import { Address, toNano } from '@ton/core';
import { Token } from '../wrappers/Token';
import { NetworkProvider } from '@ton/blueprint';
import { buildOnchainMetadata } from "../utils/jetton-helpers";

export async function run(provider: NetworkProvider) {
    //owner: Address, content: Cell, initialSupply: Int
    const owner = Address.parse("0QADO0v9Mcv_BiDizIk_hpXhZOU5zrc95neaLyFXnN5UYiQF");
    const jettonParams = {
        name: "token",
        description: "This is description of Test Jetton Token in Tact-lang of uniswap",
        symbol: "TEST",
        image: "https://avatars.githubusercontent.com/u/104382459?s=200&v=4",
    };
    let content = buildOnchainMetadata(jettonParams);
    const initialSupply = toNano('1000000000');
    const token = provider.open(await Token.fromInit(owner, content, initialSupply));

    await token.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(token.address);
    //EQAfRz73OPgZyLnoWduKCaSQmIaPn4utvCc6kZToApJBZ49U
    // run methods on `token`
}
