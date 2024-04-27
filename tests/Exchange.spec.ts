import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { Exchange } from '../wrappers/Exchange';
import '@ton/test-utils';

describe('Exchange', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let exchange: SandboxContract<Exchange>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        exchange = blockchain.openContract(await Exchange.fromInit());

        deployer = await blockchain.treasury('deployer');

        const deployResult = await exchange.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: exchange.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and exchange are ready to use
    });
});
