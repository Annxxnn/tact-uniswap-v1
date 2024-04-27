import "@stdlib/deploy";
import "./exchange.tact";
message CreateExchange {
    tokenAddress: Address;
}

contract Factory with Deployable {
    tokenToExchange: map<Address, Address>;
    init(){
        self.tokenToExchange = emptyMap();
    }

    receive(msg: CreateExchange){
        require(msg.tokenAddress != newAddress(0, 0), "invalid token address");
        require(self.tokenToExchange.get(msg.tokenAddress) == newAddress(0, 0), "exchange already exists");
        let einit: StateInit = initOf Exchange(msg.tokenAddress, myAddress());
        let exchangeAddress: Address = contractAddress(einit);
        send(SendParamters{
                to: exchangeAddress,
                value: ton("0.1"),
                mode: SendIgnoreErrors,
                code: einit.code,
                data: einit.data,
                body: "deploy".asComment()
            }
        );
        self.tokenToExchange.set(msg.tokenAddress, exchangeAddress);
    }

    get fun getExchange(tokenAddress: Address): Address {}
}