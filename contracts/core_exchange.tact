import "@stdlib/deploy";
import "@stdlib/content";
import "./jetton.tact";
struct Allowances {
    allowance: map<Address, Int>;
}
struct TokenTOTonInput {
    tokens_sold: Int;
    min_ton: Int;
    recipient: Address;
    is_token_transfer: Bool;
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
/////////////swap message/////////////////
message TonToTokenTransferInput {
    min_tokens: Int;
    recipient: Address;
    queryId: Int;
}
message TonToTolenSwapIutput {
    min_tokens: Int;
    queryId: Int;
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
    tokenToTonInput: map<Address, TokenTOTonInput>;
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
        if (msg.forward_payload ==  "add Liquidity".asSlice()){

            self.addLiqudity(tokenamount);
        }
        if (
            msg.forward_payload == "token swap ton to myself".asSlice() &&
            self.tokenToTonInput.get(ctx.sender) != null
        ) {
            let input: TokenTOTonInput = self.tokenToTonInput.get(ctx.sender)!!;
            input.is_token_transfer = true;
            require(input.tokens_sold > 0 && input.min_ton > 0, "invalid amount");
            require(input.is_token_transfer == true, "should be token transfer");
            self._tokenToTonSwapInput(input.tokens_sold, input.min_ton);
        }
        if (
            msg.forward_payload == "token swap ton to recipent".asSlice() &&
            self.tokenToTonInput.get(ctx.sender) != null
        ) {
            let input: TokenTOTonInput = self.tokenToTonInput.get(ctx.sender)!!;
            input.is_token_transfer = true;
            require(input.tokens_sold > 0 && input.min_ton > 0, "invalid amount");
            require(input.is_token_transfer == true, "should be token transfer");
            require(input.recipient != myAddress() && input.recipient != newAddress(0, 0), "invalid recipient address");
            self._tokenToTonTransferInput(input.tokens_sold, input.min_ton, input.recipient);
        }
        if(msg.forward_payload == "remove Liquidity".asSlice()){
            self.removeLiquidity(msg.query_id,msg.amount);
        }
    }

    receive(msg: TokenToTonTransferInput){
        let ctx: Context = context();
        self.tokenToTonInput.set(ctx.sender,
            TokenTOTonInput{
                tokens_sold: msg.tokens_sold,
                min_ton: msg.min_ton,
                recipient: msg.recipient,
                is_token_transfer: false
            }
        );
    }

    receive(msg: TokenToTonSwapInput){
        let ctx: Context = context();
        self.tokenToTonInput.set(ctx.sender,
            TokenTOTonInput{
                tokens_sold: msg.tokens_sold,
                min_ton: msg.min_ton,
                recipient: ctx.sender,
                is_token_transfer: false
            }
        );
    }

     fun addLiqudity(tokenAmount: Int): Int {
        let ctx: Context = context();
        require(ctx.value > 0, "invalid tonvalue");
        let total_liquidity: Int = self.totalSupply;
        if (total_liquidity > 0) {
            let ton_reserve: Int = (myBalance() - ctx.value);
            //计算lptoken的数量
            let liquidity_minted0: Int = ctx.value * total_liquidity / ton_reserve;
            let liquidity_minted1: Int = tokenAmount * total_liquidity / self.tokenReserve;
            let liquidity_minted: Int = liquidity_minted0 < liquidity_minted1 ? liquidity_minted0 : liquidity_minted1;
            //计算添加流动性用户的地址
            let liquidityToekn_address: Address = contractAddress(self.getJettonWalletInit(ctx.sender));
            self.mint(ctx.sender, liquidity_minted, myAddress());
            //balancen不为零时
            if (self.balances.get(ctx.sender) != null) {
                let balance: Int = self.balances.get(ctx.sender)!!;
                balance += liquidity_minted;
                self.balances.set(ctx.sender, balance);
            } else {
                self.balances.set(ctx.sender, liquidity_minted);
            }
            self.tokenReserve += tokenAmount;
            return liquidity_minted;
        } else {
            require(self.factoryAddress != newAddress(0, 0) &&
                    self.tokenAddress != newAddress(0, 0),
                "invalid address and value"
            );
            ///????不扣手续费时的余额
            let initial_liquidity: Int = myBalance();
            self.mint(ctx.sender, initial_liquidity, myAddress());
            self.balances.set(ctx.sender, initial_liquidity);
            self.tokenReserve += tokenAmount;
            return initial_liquidity;
        }
    }

    fun removeLiquidity(queryId: Int,amount: Int){
        let ctx: Context = context();
        let total_liquidity: Int = self.totalSupply;
        require(total_liquidity > 0, "the pool have not enough lptoken");
        let token_reserve: Int = self.tokenReserve;
        let ton_amount: Int = amount * myBalance() / total_liquidity;
        let token_amount: Int = amount * token_reserve / total_liquidity;
        //扣除balances结构中对应地址的lptoken
        let balance: Int = self.balances.get(ctx.sender)!!;
        balance -= amount;
        self.balances.set(ctx.sender, balance);
        //扣除池子中lptoken总量
        self.totalSupply -= amount;
        //发送ton_amount给消息发送者的钱包
        //发送token给消息发送者的jetton钱包
        //给exchange的token钱包发送tokenTransfer消息
        let init: StateInit = initOf JettonDefaultWallet(myAddress(),self.tokenAddress);
        send(SendParameters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                body: TokenTransfer{
                    query_id: queryId,
                    amount: token_amount,
                    sender: ctx.sender,
                    custom_payload: emptyCell(),
                    response_destination: myAddress(),
                    forward_ton_amount: ton_amount,
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
    /////////////////ton  swap  token///////////////////////////////////

     fun tonToTokenInput(ton_sold: Int, min_tokens: Int, buyer: Address, recipient: Address, queryId: Int): Int {
        require(ton_sold > 0 && min_tokens > 0, "invalid amount");
        let token_reserve: Int = self.tokenReserve;
        let tokens_bought: Int = self.getInputPrice(ton_sold, (myBalance() - ton_sold), token_reserve);
        require(tokens_bought >= min_tokens, "invalid tokens_bought amount");
        //发送tokens_bought给消息发送者recipient的jetton钱包
        let init: StateInit = initOf JettonDefaultWallet(myAddress(), recipient);
        send(SendParameters{
                to: contractAddress(init),
                value: 0,
                mode: SendIgnoreErrors,
                body: TokenTransferInternal{
                    query_id: queryId,
                    amount: tokens_bought,
                    from: myAddress(),
                    response_destination: recipient,
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

     fun _tonToTokenSwapInput(min_tokens: Int, queryId: Int): Int {
        let ctx: Context = context();
        return self.tonToTokenInput(ctx.value, min_tokens, ctx.sender, ctx.sender, queryId);
    }

     fun _tonToTokenTransferInput(min_tokens: Int, recipient: Address, queryId: Int): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0), "invalid address");
        return self.tonToTokenInput(ctx.value, min_tokens, ctx.sender, recipient, queryId);
    }

    receive(msg: TonToTokenTransferInput){
        let tokens_bought: Int = self._tonToTokenTransferInput(msg.min_tokens, msg.recipient, msg.queryId);
    }

    receive(msg: TonToTolenSwapIutput){
        let tokens_bought: Int = self._tonToTokenSwapInput(msg.min_tokens, msg.queryId);
    }

    ////////////////token swap  ton/////////////////////////
     fun tokenToTonInput(tokens_sold: Int, min_ton: Int, buyer: Address, recipient: Address): Int {
        require(tokens_sold > 0 && min_ton > 0, "invalid amount");
        let token_reserve: Int = self.tokenReserve;
        let ton_bought: Int = self.getInputPrice(tokens_sold, token_reserve, myBalance());
        require(ton_bought > min_ton, "invalid ton_bought");
        //向recipient发送ton_bought数量的ton
        send(SendParameters{to: recipient, value: ton_bought, mode: SendIgnoreErrors, body: "ton bought ".asComment()});
        self.tokenReserve += tokens_sold;
        return ton_bought;
    }

     fun _tokenToTonSwapInput(tokens_sold: Int, min_ton: Int): Int {
        let ctx: Context = context();
        return self.tokenToTonInput(tokens_sold, min_ton, ctx.sender, ctx.sender);
    }

     fun _tokenToTonTransferInput(tokens_sold: Int, min_ton: Int, recipient: Address): Int {
        let ctx: Context = context();
        require(recipient != myAddress() && recipient != newAddress(0, 0), "invalid recipient address");
        return self.tokenToTonInput(tokens_sold, min_ton, ctx.sender, recipient);
    }

    get fun getTokenReserve(): Int{
        return self.tokenReserve;
    }

    get fun getTonReserve(): Int{
        return myBalance();
    }
    ////////////////////////////
    get fun getTotalSupply(): Int{
        return self.totalSupply;
    }

    get fun getAddress(): Address{
        return myAddress();
    }
    get fun getBalances(address: Address): Int{
        return self.balances.get(address) == null ? 0 : self.balances.get(address)!!;
    }
}