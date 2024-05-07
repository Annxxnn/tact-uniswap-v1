import "@stdlib/deploy";
import "@stdlib/content";
import "./jetton.tact";
struct Allowances {
    allowance: map<Address, Int>;
}
/////////////liquidity message///////////////////
message RemoveLiquidity {
    queryId: Int;
    amount: Int;
    min_ton: Int;
    min_tokens: Int;
}
message GetExchangeAddress {
    tokenAddr: Address;
}
message TokenToExchangeAddress {
    tokenAddr: Address;
    exchangeAddr: Address;
}
/////////////swap message/////////////////
message TonToTokenTransferInput {
    min_tokens: Int;
    recipient: Address;
}
message TonToTolenSwapIutput {
    min_tokens: Int;
}
message TokenToTonTransferInput {
    tokens_sold: Int;
    min_ton: Int;
    recipient: Address;
}
message TokenToTonSwapInput {
    tokens_sold: Int;
    min_ton: Int;
}

contract CoreExchange with Deployable, Jetton {
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

    receive(msg: TokenNotification){
        let ctx: Context = context();
        let tokenamount: Int = msg.amount;
        if (msg.forward_payload == createOffchainContent("add Liqudity").asSlice()) {
            self.addLiqudity(msg.minliquidity_tokenssold, msg.maxtokens_minton);
        }
        if (msg.forward_payload == createOffchainContent("token swap ton to myself").asSlice()) {
            self._tokenToTonSwapInput(msg.minliquidity_tokenssold, msg.maxtokens_minton);
        }
        if (msg.forward_payload == createOffchainContent("token swap ton to recipent").asSlice()) {
            self._tokenToTonTransferInput(msg.minliquidity_tokenssold, msg.maxtokens_minton, msg.recipient);
        }
    }

    // @param min_liquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
    // @param max_tokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
     fun addLiqudity(min_liquidity: Int, max_tokens: Int): Int {
        let ctx: Context = context();
        require(max_tokens > 0 && ctx.value > 0, "invalid token amount and tonvalue");
        let total_liquidity: Int = self.totalSupply;
        if (total_liquidity > 0) {
            require(min_liquidity > 0, "invalid liquidity");
            let ton_reserve: Int = (myBalance() - ctx.value);
            let token_amount: Int = (ctx.value * self.tokenReserve / ton_reserve + 1);
            let liquidity_minted: Int = ctx.value * total_liquidity / ton_reserve;
            require(max_tokens >= token_amount && liquidity_minted >= min_liquidity, "Does not meet the requirements");
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
            // self.totalSupply = (total_liquidity + liquidity_minted);
            // send token to the contract from the message sender?????
            self.tokenReserve += token_amount;
            return liquidity_minted;
        } else {
            require(self.factoryAddress != newAddress(0, 0) &&
                    self.tokenAddress != newAddress(0, 0) &&
                    ctx.value >= 1000000000,
                "invalid address and value"
            );
            //得到factory合约中token对应的exchange地址,确保获取到的交易所地址等于当前合约地址。
            //self.factory.getExchange(token_addr)
            require(self.getTokenToExchangeAddress(self.tokenAddress) == myAddress(), "invalid exchange address");
            let token_amount: Int = msg.max_tokens;
            let initial_liquidity: Int = myBalance();
            //trait jetton 已经更新过了
            // self.totalSupply = initial_liquidity;
            self.mint(ctx.sender, initial_liquidity, myAddress());
            self.balances.set(ctx.sender, initial_liquidity);
            self.tokenReserve += token_amount;
            return initial_liquidity;
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
        let balance: Int = self.balances.get(liquidityToekn_address)!!;
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

    /////////////////ton  swap  token///////////////////////////////////

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

     fun _tonToTolenSwapIutput(min_tokens: Int): Int {
        let ctx: Context = context();
        return self.tonToTokenInput(ctx.value, min_tokens, ctx.sender, ctx.sender);
    }

     fun _tonToTokenTransferInput(min_tokens: Int, recipient: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0), "invalid address");
        return self.tonToTokenInput(ctx.value, min_tokens, ctx.sender, recipient);
    }

    receive(msg: TonToTokenTransferInput){
        let tokens_bought: Int = self._tonToTokenTransferInput(msg.min_tokens, msg.recipient);
    }

    receive(msg: TonToTolenSwapIutput){
        let tokens_bought: Int = self._tonToTokenTransferInput(msg.min_tokens);
    }

    ////////////////token swap  ton/////////////////////////
     fun tokenToTonInput(tokens_sold: Int, min_ton: Int, buyer: Address, recipient: Address): Int {
        require(tokens_sold > 0 && min_ton > 0, "invalid amount");
        let token_reserve: Int = self.tokenReserve;
        let ton_bought: Int = self.getInputPrice(tokens_sold, token_reserve, myBalance());
        require(ton_bought > min_ton, "invalid ton_bought");
        //向recipient发送ton_bought数量的ton
        send(SendParamters{to: recipient, value: ton_bought, mode: SendIgnoreErrors, body: "ton bought ".asComment()});
        self.tokenReserve += tokens_sold;
        return ton_bought;
    }

     fun _tokenToTonSwapInput(tokens_sold: Int, min_ton: Int): Int {
        let ctx: Context = context();
        return self.tokenToTonInput(token_sold, min_ton, ctx.sender, ctx.sender);
    }

     fun _tokenToTonTransferInput(tokens_sold: Int, min_ton: Int, recipient: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0));
        return self.tokenToTonInput(tokens_sold, min_ton, ctx.sender, recipient);
    }
}