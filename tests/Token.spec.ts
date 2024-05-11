import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Address, toNano } from '@ton/core';
import { Token } from '../wrappers/Token';
import '@ton/test-utils';
import { buildOnchainMetadata } from "../utils/jetton-helpers";
describe('Token', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let token: SandboxContract<Token>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        const owner = Address.parse("0QADO0v9Mcv_BiDizIk_hpXhZOU5zrc95neaLyFXnN5UYiQF");
        const jettonParams = {
            name: "token",
            description: "This is description of Test Jetton Token in Tact-lang of uniswap",
            symbol: "TEST",
            image: "https://avatars.githubusercontent.com/u/104382459?s=200&v=4",
        };
        let content = buildOnchainMetadata(jettonParams);
        const initialSupply = toNano('1000000000');
        token = blockchain.openContract(await Token.fromInit(owner, content, initialSupply));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await token.send(
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
            to: token.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and token are ready to use
    });
});
