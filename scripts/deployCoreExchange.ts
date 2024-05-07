import { toNano } from '@ton/core';
import { CoreExchange } from '../wrappers/CoreExchange';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const coreExchange = provider.open(await CoreExchange.fromInit());

    await coreExchange.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(coreExchange.address);

    // run methods on `coreExchange`
}
