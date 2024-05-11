import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Builder, beginCell, Slice, Address, toNano } from '@ton/core';
import { CoreExchange } from '../wrappers/CoreExchange';
import '@ton/test-utils';
import { buildOnchainMetadata } from "../utils/jetton-helpers";
describe('CoreExchange', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let coreExchange: SandboxContract<CoreExchange>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();
        let tokenAddress = Address.parse("EQAewX6C4awPSiATmkPxKn8vvgVNsPmAH80EDr0L0Nvy-haK");
        let factoryAddress = Address.parse("EQABxHhflaZLnBwpF0Dl1RJnZly8gMbhIY15oIcKDwULeIk9");
        const LPParams = {
            name: "LP token",
            description: "This is description of Test LP Token in Tact-lang of uniswap",
            symbol: "LP",
            image: "https://avatars.githubusercontent.com/u/104382459?s=200&v=4",
        };
        let content = buildOnchainMetadata(LPParams);
        coreExchange = blockchain.openContract(await CoreExchange.fromInit(tokenAddress, factoryAddress, content));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await coreExchange.send(
            deployer.getSender(),
            {
                value: toNano('0.5'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );
        //向部署的CoreExchange合约转入5个TON


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
    it('should get ton reserve', async () => {
        const tonReserve = await coreExchange.getGetTonReserve();
        console.log('tonReserve', tonReserve);
        expect(tonReserve).toBe(0n);
    });
    // it('should add liquidity', async () => {
    //     const addLiquidity = 1;
    //     for (let i = 0; i < addLiquidity; i++) {
    //         console.log(`add liquidity ${i + 1}/${addLiquidity}`);

    //         const adder = await blockchain.treasury('adder' + i);

    //         const liquidityBefore = await coreExchange.getGetTotalSupply();

    //         console.log('liquidity before adding', liquidityBefore);
    //         //转入的ton数量
    //         const tonAmount = BigInt(Math.floor(Math.random() * 100));
    //         const tokenReserveBefore = await coreExchange.getGetTokenReserve();
    //         const tonReserveBefore = await coreExchange.getGetTonReserve();
    //         //转入的token数量
    //         const tokenAmount = (tonAmount * tokenReserveBefore) / (tonReserveBefore + tonAmount);
    //         //将"add Liqudity"转换成Slice格式
    //         const addString = "add Liquidity";
    //         const addLiquiditySlice = beginCell()
    //             .storeStringTail(addString)
    //             .endCell().asSlice();

    //         const balancesBefore = await coreExchange.getGetBalances(adder.address);
    //         const addLiquidityResult = await coreExchange.send(
    //             adder.getSender(),
    //             {
    //                 value: toNano(tonAmount),
    //             },
    //             {
    //                 $$type: 'TokenNotification',
    //                 query_id: 0n,
    //                 amount: tokenAmount,
    //                 from: adder.address,
    //                 forward_payload: addLiquiditySlice.asCell()// Add a comma here
    //             }
    //         );
    //         //const owner = Address.parse("0QADO0v9Mcv_BiDizIk_hpXhZOU5zrc95neaLyFXnN5UYiQF");
    //         //计算添加的流动性
    //         const liquidity_minted0 = tonAmount * liquidityBefore / tonReserveBefore;
    //         const liquidity_minted1 = tokenAmount * liquidityBefore / tokenReserveBefore;
    //         const liquidity_minted = liquidity_minted0 < liquidity_minted1 ? liquidity_minted0 : liquidity_minted1;
    //         expect(addLiquidityResult.transactions).toHaveTransaction({
    //             from: adder.address,
    //             to: coreExchange.address,
    //             success: true,
    //         });

    //         const liquidityAfter = await coreExchange.getGetTotalSupply();

    //         console.log('liquidity after adding', liquidityAfter);

    //         expect(liquidityAfter).toBe(liquidityBefore + liquidity_minted);

    //         const balancesAfter = await coreExchange.getGetBalances(adder.address);
    //         expect(balancesAfter == balancesBefore + liquidity_minted);

    //         const tokenReserveAfter = await coreExchange.getGetTokenReserve();
    //         expect(tokenReserveAfter).toBe(tokenReserveBefore + tokenAmount);

    //         const tonReserveAfter = await coreExchange.getGetTonReserve();
    //         expect(tonReserveAfter).toBe(tonReserveBefore + tonAmount);

    //     }
    // });
});
