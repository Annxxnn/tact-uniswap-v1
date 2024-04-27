import "@stdlib/deploy";
import "@stdlib/ownable";
import "./jetton.tact";
//0QAPuiforZqXXqFH456eIR6ZqMUFJVP8Ibvh1jUkigpuGDZi
//定义消息Mint
//amount:mint jetton的数量
//receiver:接收者的地址
message Mint {
    amount: Int;
    receiver: Address;
}

//根据trait实现Jetton,每个 Jetton 都有主智能合约，用于铸造新的 Jetton、计算循环供应并提供公共信息。
contract Token with Jetton, Deployable {
    totalSupply: Int as coins;
    owner: Address;
    content: Cell;
    mintable: Bool;
    init(owner: Address, content: Cell, initialSupply: Int){
        self.totalSupply = 0;
        self.owner = owner;
        self.mintable = true;
        self.content = content;
        self.mint(self.owner, initialSupply, self.owner);
    }

    receive(msg: Mint){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not Owner");
        require(self.mintable, "Can't Mint Anymore");
        self.mint(msg.receiver, msg.amount, self.owner); // (to, amount, response_destination)
    }

    receive("Mint: 100"){
        // Public Minting
        let ctx: Context = context();
        require(self.mintable, "Can't Mint Anymore");
        self.mint(ctx.sender, 100, self.owner);
    }

    receive("Owner: MintClose"){
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not Owner");
        self.mintable = false;
    }
}