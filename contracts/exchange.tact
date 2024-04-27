import "@stdlib/deploy";
import "./jetton.tact";

contract Exchange with Deployable, Jetton {
    tokenAddress: Address;
    factoryAddress: Address;
    totalSupply: Int; // Already set initially
    mintable: Bool;
    owner: Address;
    content: Cell;
    //not in eips
    name: String;
    simple: String;
    init(_tokenAddress: Address, _factoryAddress: Address){
        self.tokenAddress = _tokenAddress;
        self.factoryAddress = _factoryAddress;
    }
}