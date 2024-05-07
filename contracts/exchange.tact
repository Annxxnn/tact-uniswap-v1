import "@stdlib/deploy";
import "./jetton.tact";
struct Allowances {
    allowance: map<Address, Int>;
}
message Mint {
    amount: Int;
    receiver: Address;
}
message AddLiquidity {
    queryId: Int;
    min_liquidity: Int;
    max_tokens: Int;
    //deadline:
}
message RemoveLiquidity {
    queryId: Int;
    amount: Int;
    min_ton: Int;
    min_tokens: Int;
}
message TonToTokenTransferInput {
    min_tokens: Int;
    recipient: Address;
}
message GetExchangeAddress {
    tokenAddr: Address;
}
message TokenToExchangeAddress {
    tokenAddr: Address;
    exchangeAddr: Address;
}

//jetton master wallet
contract Exchange with Deployable, Jetton {
    //exchange contract
    tokenAddress: Address;
    factoryAddress: Address;
    tokenReserve: Int = 0;
    balances: map<Address, Int>; //uni token (user)
    allowances: map<Address, Allowances>; //uni token
    tokenToExchange: map<Address, Address>;
    //jetton standerd
    totalSupply: Int = 0; //uni token
    mintable: Bool = true;
    owner: Address;
    content: Cell;
    init(_tokenAddress: Address, _factoryAddress: Address, content: Cell){
        self.tokenAddress = _tokenAddress;
        self.factoryAddress = _factoryAddress;
        self.owner = myAddress();
        self.content = content;
    }

    // receive(msg: Mint){
    //     let ctx: Context = context();
    //     require(ctx.sender == self.owner, "Not Owner");
    //     require(self.mintable, "Can't Mint Anymore");
    //     self.mint(msg.receiver, msg.amount, self.owner); // (to, amount, response_destination)
    // }

    receive("Owner: MintClose"){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not Owner");
        self.mintable = false;
    }

    // @param min_liquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
    // @param max_tokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
    receive(msg: AddLiquidity){
        let ctx: Context = context();
        require(msg.max_tokens > 0 && ctx.value > 0, "invalid token amount and tonvalue");
        let total_liquidity: Int = self.totalSupply;
        if (total_liquidity > 0) {
            require(msg.min_liquidity > 0, "invalid liquidity");
            let ton_reserve: Int = (myBalance() - ctx.value);
            let token_amount: Int = (ctx.value * self.tokenReserve / ton_reserve + 1);
            let liquidity_minted: Int = ctx.value * total_liquidity / ton_reserve;
            require(msg.max_tokens >= token_amount && liquidity_minted >= msg.min_liquidity,
                "Does not meet the requirements"
            );
            // Add Liquidity(mint LP token to the address that the owner is the message sender)
            // send(SendParamters{});
            let liquidityToekn_address: Address = self.getwalletaddress(ctx.sender);
            //to: Address, amount: Int, response_destination: Address
            self.mint(ctx.sender, liquidity_minted, myAddress());
            //balancen不为零时
            if (self.balances.get(liquidityToekn_address) != null) {
                let balance: Int = self.balances.get(liquidityToekn_address)!!;
                balance += liquidity_minted;
                self.balances.set(liquidityToekn_address, balance);
            } else {
                self.balances.set(liquidityToekn_address, liquidity_minted);
            }
            //trait jetton 已经更新过了
            //self.totalSupply = (total_liquidity + liquidity_minted);
            // send token to the contract from the message sender?????
            let init: StateInit = initOf JettonDefaultWallet(myAddress(), ctx.sender);
            send(SendParamters{
                    to: contractAddress(init),
                    value: 0,
                    mode: SendIgnoreErrors,
                    //这个消息需要权限，发不出去
                    body: TokenTransfer{
                        queryId: msg.queryId,
                        amount: token_amount,
                        destination: myAddress(),
                        response_destination: myAddress(),
                        custom_payload: emptyCell(),
                        forward_ton_amount: 0,
                        forward_payload: emptySlice()
                    }.toCell(),
                    code: init.code,
                    data: init.data
                }
            );
            self.tokenReserve += token_amount;
        } else {
            require(self.factoryAddress != newAddress(0, 0) &&
                    self.tokenAddress != newAddress(0, 0) &&
                    ctx.value >= 1000000000
            );
            //得到factory合约中token对应的exchange地址,确保获取到的交易所地址等于当前合约地址。
            //self.factory.getExchange(token_addr)
            require(self.getTokenToExchangeAddress(token_addr) == myAddress());
            let token_amount: Int = msg.max_tokens;
            let initial_liquidity: Int = myBalance();
            //trait jetton 已经更新过了
            // self.totalSupply = initial_liquidity;
            self.mint(ctx.sender, initial_liquidity, myAddress());
            self.balances.set(ctx.sender, initial_liquidity);
            // send token to the contract from the message sender????
            // send TokenTransfer message
            let init: StateInit = initOf JettonDefaultWallet(myAddress(), ctx.sender);
            send(SendParamters{
                    to: contractAddress(init),
                    value: 0,
                    mode: SendIgnoreErrors,
                    //这个消息需要权限，发不出去
                    body: TokenTransfer{
                        queryId: msg.queryId,
                        amount: token_amount,
                        destination: myAddress(),
                        response_destination: myAddress(),
                        custom_payload: emptyCell(),
                        forward_ton_amount: 0,
                        forward_payload: emptySlice()
                    }.toCell(),
                    code: init.code,
                    data: init.data
                }
            );
            self.tokenReserve += token_amount;
        }
    }

    //# @param amount Amount of UNI burned.
    //# @param min_eth Minimum ETH withdrawn.
    //# @param min_tokens Minimum Tokens withdrawn.
    receive(msg: RemoveLiquidity){
        let ctx: Context = context();
        require(msg.amount > 0 && msg.min_ton > 0 && msg.min_tokens > 0, "invalid remove input");
        let total_liquidity: Int = self.totalSupply;
        require(total_liquidity > 0, "the pool have not enough lptoken");
        let token_reserve: Int = self.tokenReserve;
        let ton_amount: Int = msg.amount * myBalance() / total_liquidity;
        let token_amount: Int = msg.amount * token_reserve / total_liquidity;
        require(ton_amount >= msg.min_ton && token_amount >= msg.min_tokens, "Does not meet the requirements");
        //扣除balances结构中对应地址的lptoken
        let liquidityToekn_address: Address = self.getwalletaddress(ctx.sender);
        let balance: Int = self.balances.get(liquidityToekn_address);
        balance -= msg.amount;
        self.balances.set(liquidityToekn_address, balance);
        //扣除池子中lptoken总量
        // self.totalSupply -= msg.amount;
        //发送TokenBurnNotification消息
        send(SendParamters{
                to: myAddress(),
                value: 0,
                mode: SendIgnoreErrors,
                body: TokenBurnNotification{
                    queryId: msg.queryId,
                    amount: msg.amount,
                    sender: myAddress(),
                    response_destination: myAddress()
                }.toCell()
            }
        );
        //发送ton_amount给消息发送者的钱包
        send(SendParamters{
                to: ctx.sender,
                value: ton_amount,
                mode: SendIgnoreErrors,
                body: "remove liquidity ".asComment()
            }
        );
        //发送token给消息发送者的jetton钱包
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), ctx.sender);
        send(SendParamters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                body: TokenTransferInternal{
                    queryId: msg.queryId,
                    amount: token_amount,
                    from: myAddress(),
                    response_destination: myAddress(),
                    forward_ton_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: init.code,
                data: init.data
            }
        );
        self.tokenReserve -= token_amount;
    }

    // # @dev Pricing function for converting between ETH and Tokens.
    // # @param input_amount Amount of ETH or Tokens being sold.
    // # @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.
    // # @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.
    // # @return Amount of ETH or Tokens bought.
     fun getInputPrice(input_amount: Int, input_reserve: Int, output_reserve: Int): Int {
        require(input_reserve > 0 && output_reserve > 0, "invalid reserve amount");
        //输入单位的0.3%作为交易费用
        let input_amount_with_fee: Int = input_amount * 997;
        let numerator: Int = input_amount_with_fee * output_reserve;
        let denominator: Int = (input_reserve * 1000 + input_amount_with_fee);
        return numerator / denominator;
    }

    // # @dev Pricing function for converting between ETH and Tokens.
    // # @param output_amount Amount of ETH or Tokens being bought.
    // # @param input_reserve Amount of ETH or Tokens (input type) in exchange reserves.
    // # @param output_reserve Amount of ETH or Tokens (output type) in exchange reserves.
    // # @return Amount of ETH or Tokens sold.

     fun getOutputPrice(output_amount: Int, input_reserve: Int, output_reserve: Int): Int {
        require(input_reserve > 0 && output_reserve > 0, "invalid reserve amount");
        let numerator: Int = input_reserve * output_amount * 1000;
        let denominator: Int = (output_reserve - output_amount) * 997;
        return (numerator / denominator + 1);
    }
    ////////////////////////////////////////////////////

     fun tonToTokenInput(ton_sold: Int, min_tokens: Int, buyer: Address, recipient: Address): Int {
        require(ton_sold > 0 && min_tokens > 0, "invalid amount");
        let token_reserve: Int = self.tokenReserve;
        let tokens_bought: Int = self.getInputPrice(ton_sold, (myBalance() - ton_sold), token_reserve);
        require(tokens_bought >= min_tokens, "invalid tokens_bought amount");
        //发送tokens_bought给消息发送者recipient的jetton钱包
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), recipient);
        send(SendParamters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                body: TokenTransferInternal{
                    queryId: msg.queryId,
                    amount: tokens_bought,
                    from: myAddress(),
                    response_destination: myAddress(),
                    forward_ton_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: init.code,
                data: init.data
            }
        );
        self.tokenReserve -= tokens_bought;
        return tokens_bought;
    }

    get fun _default_() {
        let ctx: Context = context();
        self.tonToTokenInput(ctx.value, 1, ctx.sender, ctx.sender);
    }
    //get 还是 receive？？？

    get fun tonToTolenSwapIutput(min_tokens: Int): Int {
        let ctx: Context = context();
        return self.tonToTokenInput(ctx.value, min_tokens, ctx.sender, ctx.sender);
    }

     fun _tonToTokenTransferInput(min_tokens: Int, recipient: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0), "invalid address");
        return self.tonToTokenInput(ctx.value, min_tokens, ctx.sender, recipient);
    }

    get fun tonToTokenTransferInput(min_tokens: Int, recipient: Address): Int {
        return self._tonToTokenTransferInput(min_tokens, recipient);
    }

    receive(msg: TonToTokenTransferInput){
        let tokens_bought: Int = self._tonToTokenTransferInput(msg.min_tokens, msg.recipient);
    }

    ////////////////////////////////////////

     fun tonToTokenOutput(tokens_bought: Int, max_ton: Int, buyer: Address, recipient: Address): Int {
        require(tokens_bought > 0 && max_ton > 0, "invalid amount");
        let token_reserve: Int = self.tokenReserve;
        let ton_sold: Int = self.getOutputPrice(tokens_bought, (myBalance() - max_ton), token_reserve);
        let ton_refund: Int = (max_ton - ton_sold);
        if (ton_refund > 0) {
            //向buyer发送剩余的ton
            send(SendParamters{to: buyer, value: ton_refund, mode: SendIgnoreErrors, body: "refund ton ".asComment()});
        }
        //向recipient发送tokens_bought的代币
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), recipient);
        send(SendParamters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                body: TokenTransferInternal{
                    queryId: msg.queryId,
                    amount: tokens_bought,
                    from: myAddress(),
                    response_destination: myAddress(),
                    forward_ton_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: init.code,
                data: init.data
            }
        );
        self.tokenReserve -= tokens_bought;
        return ton_sold;
    }

    get fun tonToTokenSwapOutput(tokens_bought: Int): Int {
        let ctx: Context = context();
        return self.tonToTokenOutput(tokens_bought, ctx.value, ctx.sender, ctx.sender);
    }

    get fun tonToTokenTransferOutput(tokens_bought: Int, recipient: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0));
        return self.tonToTokenOutput(tokens_bought, ctx.value, ctx.sender, recipient);
    }

    /////////////////////////////////////

     fun tokenToTonInput(tokens_sold: Int, min_ton: Int, buyer: Address, recipient: Address): Int {
        require(tokens_sold > 0 && min_ton > 0, "invalid amount");
        let token_reserve: Int = self.tokenReserve;
        let ton_bought: Int = self.getInputPrice(tokens_sold, token_reserve, myBalance());
        require(ton_bought > min_ton, "invalid ton_bought");
        //向recipient发送ton_bought数量的ton
        send(SendParamters{to: recipient, value: ton_bought, mode: SendIgnoreErrors, body: "ton bought ".asComment()});
        //从buyer向合约本身转入token_sold的代币
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), buyer);
        send(SendParamters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                //这个消息需要权限，发不出去
                body: TokenTransfer{
                    queryId: msg.queryId,
                    amount: tokens_sold,
                    destination: myAddress(),
                    response_destination: myAddress(),
                    custom_payload: emptyCell(),
                    forward_ton_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: init.code,
                data: init.data
            }
        );
        self.tokenReserve += tokens_sold;
        return ton_bought;
    }

    get fun tokenToTonSwapInput(tokens_sold: Int, min_ton: Int): Int {
        let ctx: Context = context();
        return self.tokenToTonInput(token_sold, min_ton, ctx.sender, ctx.sender);
    }

    get fun tokenToTonTransferInput(tokens_sold: Int, min_ton: Int, recipient: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0));
        return self.tokenToTonInput(tokens_sold, min_ton, ctx.sender, recipient);
    }

    ////////////////////////////////

     fun tokenToTonOutput(ton_bought: Int, max_tokens: Int, buyer: Address, recipient: Address): Int {
        require(ton_bought > 0 && max_ton > 0, "invalid amount");
        let token_reserve: Int = self.tokenReserve;
        let tokens_sold: Int = self.getOutputPrice(ton_bought, token_reserve, myBalance());
        require(max_tokens >= tokens_sold);
        //向recipient发送ton_bought的ton
        send(SendParamters{to: recipient, value: ton_bought, mode: SendIgnoreErrors, body: "ton bought ".asComment()});
        //从buyer向合约本身发送tokens_sold的代币
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), buyer);
        send(SendParamters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                //这个消息需要权限，发不出去
                body: TokenTransfer{
                    queryId: msg.queryId,
                    amount: tokens_sold,
                    destination: myAddress(),
                    response_destination: myAddress(),
                    custom_payload: emptyCell(),
                    forward_ton_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: init.code,
                data: init.data
            }
        );
        self.tokenReserve += tokens_bought;
        return tokens_sold;
    }

    get fun tokenToTonSwapOutput(ton_bought: Int, max_tokens: Int): Int {
        let ctx: Context = context();
        return self.tokenToTonOutput(ton_bought, max_tokens, ctx.sender, ctx.sender);
    }

    get fun tokenToTonTransferOutput(ton_bought: Int, max_tokens: Int, recipient: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0));
        return self.tokenToTonOutput(ton_bought, max_tokens, ctx.sender, recipient);
    }

    ///////////////////////////////////

     fun tokenToTokenInput(tokens_sold: Int,
        min_tokens_bought: Int,
        min_ton_bought: Int,
        buyer: Address,
        recipient: Address,
        exchange_addr: Address): Int {
        let ctx: Context = context();
        require(tokens_slpd > 0 && min_tokens_bought > 0 && min_ton_bought > 0);
        require(exchange_addr != myAddress() && exchange_addr != newAddress(0, 0));
        let token_reserve: Int = self.tokenReserve;
        let ton_bought: Int = self.getInputPrice(tokens_sold, token_reserve, myBalance());
        require(ton_bought >= min_ton_bought);
        //从buyer向合约本身转移tokens_sold数量的代币
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), buyer);
        send(SendParamters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                //这个消息需要权限，发不出去,要改
                body: TokenTransfer{
                    queryId: msg.queryId,
                    amount: tokens_sold,
                    destination: myAddress(),
                    response_destination: myAddress(),
                    custom_payload: emptyCell(),
                    forward_ton_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: init.code,
                data: init.data
            }
        );
        self.tokenReserve += tokens_sold;
        //向exchange_addr发送TonToTokenTransferInput消息调用_tonToTokenTransferInput方法
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), exchange_addr);
        send(SendParamters{
                to: contractAddress(init),
                value: ton_bought,
                mode: SendIgnoreErrors,
                body: TonToTokenTransferInput{min_tokens: min_tokens_bought, recipient: recipient}.toCell(),
                code: init.code,
                data: init.data
            }
        );
        let tokens_bought: Int = self.getInputPrice(ton_bought, (myBalance() - ton_bought), token_reserve);
        return tokens_bought;
    }

    receive(msg: TokenToExchangeAddress){
        self.tokenToExchange.set(msg.tokenAddr.msg.exchangeAddr);
    }

    get fun tokenToTokenSwapInput(tokens_sold: Int,
        min_tokens_bought: Int,
        min_ton_bought: Int,
        token_addr: Address): Int {
        let ctx: Context = context();
        let exchange_addr: Address = self.getTokenToExchangeAddress(token_addr);
        return self.tokenToTokenInput(tokens_sold, min_tokens_bought, min_ton_bought, ctx.sender, exchange_addr);
    }

     fun getTokenToExchangeAddress(token_addr: Address): Address {
        //得到指定token的对应的exchange的合约地址
        if (self.tokenToExchange.get(token_addr) != null) {
            let exchange_addr: Address = self.tokenToExchange.get(token_addr);
        } else {
            send(SendParamters{
                    to: self.factoryAddress,
                    value: 0,
                    mode: SendIgnoreErrors,
                    body: GetExchangeAddress{tokenAddr: token_addr}.toCell()
                }
            );
            let exchange_addr: Address = self.tokenToExchange.get(token_addr);
        }
        return exchange_addr;
    }

    get fun tokenToTokenTransferInput(tokens_sold: Int,
        min_tokens_bought: Int,
        min_ton_bought: Int,
        recipient: Address,
        token_addr: Address): Int {
        let exchange_addr: Address = self.getTokenToExchangeAddress(token_addr);
        return self.tokenToTokenInput(tokens_sold, min_tokens_bought, min_ton_bought, exchange_addr);
    }
    //////////////////////////////
    // fun tokenToTokenOutput(tokens_bought: Int,max_tokens_sold: Int,max_ton_sold: Int,buyer: Address,recipient: Address,exchange_addr: Address): Int{
    //     require(tokens_bought>0 &&max_ton_sold>0);
    //     require(exchange_addr!=myAddress()&&exchange_addr!= newAddress(0,0));
    //     let ton_bought: Int =
    // }

    // get fun tokenToTokenSwapOutput(tokens_bought: Int,max_tokens_sold: Int,max_ton_sold: Int,token_addr: Address): Int{
    //      let exchange_addr: Address = self.getTokenToExchangeAddress(token_addr);
    // }

    // get fun tokenToTokenTransferOutput(tokens_bought: Int,max_tokens_sold: Int,max_ton_sold: Int,recipient: Address,token_addr: Address): Int{
    //      let exchange_addr: Address = self.getTokenToExchangeAddress(token_addr);
    // }

    //////////////////////////////////

    get fun tokenToExchangeSwapInput(tokens_sold: Int,
        min_tokens_bought: Int,
        min_ton_bought: Int,
        exchange_addr: Address): Int {
        let ctx: Context = context();
        return
            self.tokenToTokenInput(tokens_sold,
                min_tokens_bought,
                min_ton_bought,
                ctx.sender,
                ctx.sender,
                exchange_addr
            );
    }

    get fun tokenToExchangeTransferInput(tokens_sold: Int,
        min_tokens_bought: Int,
        min_ton_bought: Int,
        recipient: Address,
        exchange_addr: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress());
        return
            self.tokenToTokenInput(tokens_sold,
                min_tokens_bought,
                min_ton_bought,
                ctx.sender,
                recipient,
                exchange_addr
            );
    }
    //////////////////////////////////

    // get fun tokenToExchangeSwapOutput(tokens_bought: Int,max_tokens_sold: Int,max_ton_sold: Int,exchange_addr: Address): Int{

    // }

    // get fun tokenToExchangeTransferOutput(tokens_bought: Int,max_tokens_sold: Int,max_ton_sold: Int,recipient: Address,exchange_addr: Address): Int{

    // }

    ////////////////////////////////

    get fun getTonToTokenInputPrice(ton_sold: Int): Int {
        require(ton_sold > 0);
        let token_reserve: Int = self.tokenReserve;
        return self.getInputPrice(ton_sold, myBalance(), token_reserve);
    }

    get fun getTonToTokenOutputPrice(tokens_bought: Int): Int {
        return self._getTonToTokenOutputPrice(tokens_bought);
    }

     fun _getTonToTokenOutputPrice(tokens_bought: Int): Int {
        require(tokens_bought > 0);
        let token_reserve: Int = self.tokenReserve;
        let ton_sold: Int = self.getOutputPrice(tokens_bought, myBalance(), token_reserve);
        return ton_sold;
    }

    get fun getTokenToTonInputPrice(tokens_sold: Int): Int {
        require(tokens_sold > 0);
        let token_reserve: Int = self.tokenReserve;
        let ton_bought: Int = self.getInputPrice(tokens_sold, token_reserve, myBalance());
        return ton_bought;
    }

    get fun getTokenToTonOutputPrice(ton_bought: Int): Int {
        require(ton_bought > 0);
        let token_reserve: Int = self.tokenReserve;
        return self.getOutputPrice(ton_bought, token_reserve, myBalance());
    }

    /////////////////////////////////

    get fun tokenAddress(): Address {
        return self.tokenAddress;
    }

    get fun factoryAddress(): Address {
        return self.factoryAddress;
    }
}