import { toNano } from '@ton/core';
import { Factory } from '../wrappers/Factory';
import { NetworkProvider } from '@ton/blueprint';
import { buildOnchainMetadata } from "../utils/jetton-helpers";
//EQABxHhflaZLnBwpF0Dl1RJnZly8gMbhIY15oIcKDwULeIk9
export async function run(provider: NetworkProvider) {
    const LPParams = {
        name: "LP token",
        description: "This is description of Test LP Token in Tact-lang of uniswap",
        symbol: "LP",
        image: "https://avatars.githubusercontent.com/u/104382459?s=200&v=4",
    };
    let content = buildOnchainMetadata(LPParams);
    const factory = provider.open(await Factory.fromInit(content));

    await factory.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(factory.address);

    // run methods on `factory`
}
