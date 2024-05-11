import "@stdlib/deploy";
// import "./exchange.tact";
import "./core_exchange.tact";
message CreateExchange {
    tokenAddress: Address;
    response_address: Address?;
}
message InitializeFactory {
    template: Address;
}

// message NewExchangeNotification {
//     toeknAddress: Address;
//     exchangeAddress: Address;
// }

contract Factory with Deployable {
    exchangeTemplate: Address;
    tokenCount: Int;
    tokenToExchange: map<Address, Address>;
    exchangeToToken: map<Address, Address>;
    idToToken: map<Int, Address>;
    content: Cell;
    init(content: Cell){
        self.exchangeTemplate = newAddress(0, 0);
        self.tokenCount = 0;
        self.content = content;
    }

    receive(msg: InitializeFactory){
        require(self.exchangeTemplate == newAddress(0, 0), "template already exist");
        require(msg.template != newAddress(0, 0), "Invalid message");
        self.exchangeTemplate = msg.template;
    }

    receive(msg: CreateExchange){
        require(msg.tokenAddress != newAddress(0, 0), "invalid token address");
        require(self.tokenToExchange.get(msg.tokenAddress) == newAddress(0, 0), "exchange already exists");
        let einit: StateInit = initOf CoreExchange(msg.tokenAddress, myAddress(), self.content);
        let exchangeAddress: Address = contractAddress(einit);
        send(SendParameters{
                to: exchangeAddress,
                value: ton("0.1"),
                mode: SendIgnoreErrors,
                code: einit.code,
                data: einit.data,
                body: "deploy".asComment()
            }
        );
        // if(msg.response_address != null){
        //     send(SendParameters{
        //         to:myAddress(),
        //         value:0,
        //         mode: SendIgnoreErrors,
        //         body: NewExchangeNotification{

        //         }
        //     })
        // }
        self.tokenToExchange.set(msg.tokenAddress, exchangeAddress);
        self.exchangeToToken.set(exchangeAddress, msg.tokenAddress);
        self.tokenCount += 1;
        self.idToToken.set(self.tokenCount, msg.tokenAddress);
    }

    // receive(msg: GetExchangeAddress){
    //     let ctx: Context = context();
    //     let exchange_addr: Address = self.tokenToExchange.get(msg.tokenAddr)!!;
    //     send(SendParameters{
    //             to: ctx.sender,
    //             value: 0,
    //             mode: SendIgnoreErrors,
    //             body: TokenToExchangeAddress{tokenAddr: msg.tokenAddr, exchangeAddr: exchange_addr}.toCell()
    //         }
    //     );
    // }

    get fun getExchange(tokenAddress: Address): Address {
        return self.tokenToExchange.get(tokenAddress)!!;
    }

    get fun getToken(exchangeAddress: Address): Address {
        return self.exchangeToToken.get(exchangeAddress)!!;
    }

    get fun getTokenWithId(token_id: Int): Address {
        return self.idToToken.get(token_id)!!;
    }

    //  fun getContent(name: String, simple: String): Cell {
    //     let strContent: StringBuilder = beginString();
    //     strContent.append(name);
    //     strContent.append(simple);
    //     return strContent.toCell();
    // }
}