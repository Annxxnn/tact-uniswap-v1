import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { CoreExchange } from '../wrappers/CoreExchange';
import '@ton/test-utils';

describe('CoreExchange', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let coreExchange: SandboxContract<CoreExchange>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        coreExchange = blockchain.openContract(await CoreExchange.fromInit());

        deployer = await blockchain.treasury('deployer');

        const deployResult = await coreExchange.send(
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
            to: coreExchange.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and coreExchange are ready to use
    });
});
