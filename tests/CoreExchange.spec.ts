import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { contractAddress, beginCell, Address, toNano } from '@ton/core';
import { CoreExchange } from '../wrappers/CoreExchange';
import '@ton/test-utils';
import { buildOnchainMetadata } from "../utils/jetton-helpers";
import { JettonDefaultWallet } from '../build/CoreExchange/tact_JettonDefaultWallet';
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
                bounce: false,
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
        // await coreExchange.send(
        //     deployer.getSender(),
        //     {
        //         value: toNano('5'),
        //     },

        // );
        const tonReserve = await coreExchange.getGetTonReserve();
        console.log('tonReserve', tonReserve);
        expect(tonReserve).toBe(0n);
    });
    it('should add liquidity', async () => {

        const adder = await blockchain.treasury('adder');
        const liquidityBefore = await coreExchange.getGetTotalSupply();
        if (liquidityBefore == 0n) {
            const adder = await blockchain.treasury('adder');

            const liquidityBefore = await coreExchange.getGetTotalSupply();

            console.log('liquidity before adding', liquidityBefore);
            //转入的ton数量
            const tonAmount = 2n;
            const tokenReserveBefore = await coreExchange.getGetTokenReserve();
            const tonReserveBefore = await coreExchange.getGetTonReserve();
            //转入的token数量
            const tokenAmount = 1n;
            //将"add Liqudity"转换成Slice格式
            const addString = "add Liquidity";
            const addLiquiditySlice = beginCell()
                .storeStringTail(addString)
                .endCell().asSlice();
            console.log("---------------------------");
            const balancesBefore = await coreExchange.getGetBalances(adder.address);
            console.log('balances before adding', balancesBefore);
            const addLiquidityResult = await coreExchange.send(
                adder.getSender(),
                {
                    value: toNano(tonAmount),
                },
                {
                    $$type: 'TokenNotification',
                    query_id: 0n,
                    amount: toNano(tokenAmount),
                    from: adder.address,
                    forward_payload: addLiquiditySlice.asCell()// Add a comma here
                }
            );

            //const owner = Address.parse("0QADO0v9Mcv_BiDizIk_hpXhZOU5zrc95neaLyFXnN5UYiQF");
            //计算添加的流动性
            console.log("---------------------------")
            const tonReserveAfter = await coreExchange.getGetTonReserve();
            console.log('tonReserveAfter', tonReserveAfter);
            const liquidity_minted = toNano(tonAmount);
            expect(addLiquidityResult.transactions).toHaveTransaction({
                from: adder.address,
                to: coreExchange.address,
                success: true,
            });
            ///////////////////////////////
            const liquidityAfter = await coreExchange.getGetTotalSupply();
            console.log('liquidity after adding', liquidityAfter);
            const balancesAfter = await coreExchange.getGetBalances(adder.address);
            console.log('balances after adding', balancesAfter);
            const tokenReserveAfter = await coreExchange.getGetTokenReserve();
            console.log('tokenReserveAfter', tokenReserveAfter);

            expect(liquidityAfter).toEqual(liquidityBefore + liquidity_minted);

            expect(balancesAfter).toEqual(balancesBefore + liquidity_minted);

            expect(tokenReserveAfter).toEqual(tokenReserveBefore + toNano(tokenAmount));

            expect(tonReserveAfter).toBeLessThan(tonReserveBefore + toNano(tonAmount));

        }
        const addLiquiditycount = 3;
        for (let i = 0; i < addLiquiditycount; i++) {
            console.log('--------------' + i + 'th add liquidity---------------');
            //获取接收lp token的用户的jetton地址
            const master = await coreExchange.getGetAddress();
            let new_owner_jetton_wallet = await JettonDefaultWallet.fromInit(adder.address, master);
            console.log('new_owner_jetton_wallet', new_owner_jetton_wallet.address);
            const provider = blockchain.provider(new_owner_jetton_wallet.address, new_owner_jetton_wallet.init);
            const lpbalanceafterthefirst = (await new_owner_jetton_wallet.getGetWalletData(provider)).balance
            console.log('lpbalanceafterthefirst:' + i, lpbalanceafterthefirst);
            //第二次添加流动性
            const liquidityAftertheFirst = await coreExchange.getGetTotalSupply();
            console.log('liquidity after adding ' + i, liquidityAftertheFirst);
            //转入的ton数量
            const tonAmount = 2n;
            const tokenReserveBeforethefirst = await coreExchange.getGetTokenReserve();
            console.log('tokenReserveBeforethefirst' + i, tokenReserveBeforethefirst);
            const tonReserveBeforethefirst = await coreExchange.getGetTonReserve();
            console.log('tonReserveBeforethefirst' + i, tonReserveBeforethefirst);
            //转入的token数量
            const tokenAmount = toNano(toNano(tonAmount) * tokenReserveBeforethefirst) / toNano(tonReserveBeforethefirst + toNano(tonAmount));
            console.log('tokenAmount' + i, tokenAmount);
            //将"add Liqudity"转换成Slice格式
            const addString = "add Liquidity";
            const addLiquiditySlice = beginCell()
                .storeStringTail(addString)
                .endCell().asSlice();

            const balancesBeforethefirst = await coreExchange.getGetBalances(adder.address);
            console.log('balances after adding first' + i, balancesBeforethefirst);
            const addLiquidityResult = await coreExchange.send(
                adder.getSender(),
                {
                    value: toNano(tonAmount),
                },
                {
                    $$type: 'TokenNotification',
                    query_id: 0n,
                    amount: tokenAmount,
                    from: adder.address,
                    forward_payload: addLiquiditySlice.asCell()// Add a comma here
                }
            );
            //const owner = Address.parse("0QADO0v9Mcv_BiDizIk_hpXhZOU5zrc95neaLyFXnN5UYiQF");
            //计算添加的流动性
            const liquidity_minted0 = toNano(tonAmount) * liquidityAftertheFirst / tonReserveBeforethefirst;
            const liquidity_minted1 = tokenAmount * liquidityAftertheFirst / tokenReserveBeforethefirst;
            const liquidity_minted = liquidity_minted0 < liquidity_minted1 ? liquidity_minted0 : liquidity_minted1;
            console.log("liquidity_minted0:" + i, liquidity_minted0);
            console.log("liquidity_minted1:" + i, liquidity_minted1);
            console.log("liquidity_minted:" + i, liquidity_minted);
            expect(addLiquidityResult.transactions).toHaveTransaction({
                from: adder.address,
                to: coreExchange.address,
                success: true,
            });

            const liquidityAftertwice = await coreExchange.getGetTotalSupply();

            console.log('liquidity after adding' + i, liquidityAftertwice);

            expect(liquidityAftertwice).toEqual(liquidityAftertheFirst + liquidity_minted);

            const balancesAfter = await coreExchange.getGetBalances(adder.address);
            console.log('balances after adding' + i, balancesAfter);
            expect(balancesAfter).toEqual(balancesBeforethefirst + liquidity_minted);

            const tokenReserveAfter = await coreExchange.getGetTokenReserve();
            console.log('tokenReserveAfter' + i, tokenReserveAfter);
            expect(tokenReserveAfter).toEqual(tokenReserveBeforethefirst + tokenAmount);

            const tonReserveAfter = await coreExchange.getGetTonReserve();
            console.log('tonReserveAfter' + i, tonReserveAfter);
            expect(tonReserveAfter).toBeLessThan(tonReserveBeforethefirst + toNano(tonAmount));

            const lpbalanceafter = (await new_owner_jetton_wallet.getGetWalletData(provider)).balance
            console.log('lpbalanceafter' + i, lpbalanceafter);
            expect(lpbalanceafter).toEqual(lpbalanceafterthefirst + liquidity_minted);
        }
    });

    // it('should add liquidity first', async () => {
    //     const adder = await blockchain.treasury('adder');

    //     const liquidityBefore = await coreExchange.getGetTotalSupply();

    //     console.log('liquidity before adding', liquidityBefore);
    //     //转入的ton数量
    //     const tonAmount = 2n;
    //     const tokenReserveBefore = await coreExchange.getGetTokenReserve();
    //     const tonReserveBefore = await coreExchange.getGetTonReserve();
    //     //转入的token数量
    //     const tokenAmount = 1n;
    //     //将"add Liqudity"转换成Slice格式
    //     const addString = "add Liquidity";
    //     const addLiquiditySlice = beginCell()
    //         .storeStringTail(addString)
    //         .endCell().asSlice();
    //     console.log("---------------------------");
    //     const balancesBefore = await coreExchange.getGetBalances(adder.address);
    //     console.log('balances before adding', balancesBefore);
    //     const addLiquidityResult = await coreExchange.send(
    //         adder.getSender(),
    //         {
    //             value: toNano(tonAmount),
    //         },
    //         {
    //             $$type: 'TokenNotification',
    //             query_id: 0n,
    //             amount: toNano(tokenAmount),
    //             from: adder.address,
    //             forward_payload: addLiquiditySlice.asCell()// Add a comma here
    //         }
    //     );
    //     //const owner = Address.parse("0QADO0v9Mcv_BiDizIk_hpXhZOU5zrc95neaLyFXnN5UYiQF");
    //     //计算添加的流动性
    //     console.log("---------------------------")
    //     const tonReserveAfter = await coreExchange.getGetTonReserve();
    //     console.log('tonReserveAfter', tonReserveAfter);
    //     const liquidity_minted = toNano(tonAmount);
    //     expect(addLiquidityResult.transactions).toHaveTransaction({
    //         from: adder.address,
    //         to: coreExchange.address,
    //         success: true,
    //     });
    //     ///////////////////////////////
    //     const liquidityAfter = await coreExchange.getGetTotalSupply();
    //     console.log('liquidity after adding', liquidityAfter);
    //     const balancesAfter = await coreExchange.getGetBalances(adder.address);
    //     console.log('balances after adding', balancesAfter);
    //     const tokenReserveAfter = await coreExchange.getGetTokenReserve();
    //     console.log('tokenReserveAfter', tokenReserveAfter);
    //     //获取接收lp token的用户的jetton地址
    //     const master = await coreExchange.getGetAddress();
    //     let new_owner_jetton_wallet = await JettonDefaultWallet.fromInit(adder.address, master);
    //     console.log('new_owner_jetton_wallet', new_owner_jetton_wallet.address);
    //     const provider = blockchain.provider(new_owner_jetton_wallet.address, new_owner_jetton_wallet.init);
    //     const lpbalanceafter = (await new_owner_jetton_wallet.getGetWalletData(provider)).balance
    //     console.log('lpbalanceafter', lpbalanceafter);

    //     expect(liquidityAfter).toEqual(liquidityBefore + liquidity_minted);

    //     expect(balancesAfter).toEqual(balancesBefore + liquidity_minted);

    //     expect(tokenReserveAfter).toEqual(tokenReserveBefore + toNano(tokenAmount));

    //     expect(tonReserveAfter).toBeLessThan(tonReserveBefore + toNano(tonAmount));

    //     expect(lpbalanceafter).toEqual(liquidity_minted);


    // });
    it('should remove liquidity', async () => {
    })

});
