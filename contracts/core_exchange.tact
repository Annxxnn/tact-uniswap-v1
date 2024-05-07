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
}