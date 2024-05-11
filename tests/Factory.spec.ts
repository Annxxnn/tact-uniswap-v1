import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { Factory } from '../wrappers/Factory';
import '@ton/test-utils';
import { buildOnchainMetadata } from "../utils/jetton-helpers";
describe('Factory', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let factory: SandboxContract<Factory>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        const LPParams = {
            name: "LP token",
            description: "This is description of Test LP Token in Tact-lang of uniswap",
            symbol: "LP",
            image: "https://avatars.githubusercontent.com/u/104382459?s=200&v=4",
        };
        let content = buildOnchainMetadata(LPParams);
        factory = blockchain.openContract(await Factory.fromInit(content));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await factory.send(
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
            to: factory.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and factory are ready to use
    });

});
