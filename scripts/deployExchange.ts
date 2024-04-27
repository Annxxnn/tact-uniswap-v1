import { toNano } from '@ton/core';
import { Exchange } from '../wrappers/Exchange';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const exchange = provider.open(await Exchange.fromInit());

    await exchange.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(exchange.address);

    // run methods on `exchange`
}
