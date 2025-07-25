// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "genidex_contract/contracts/test/TestToken.sol";
import {GeniDex, GeniDexHelper} from "genidex_contract/foundry/src/GeniDexHelper.sol";
import {GeniToken, GeniTokenHelper} from "geni_token/foundry/test/GeniTokenHelper.sol";
import {GeniRewarder, GeniRewarderHelper} from "./GeniRewarderHelper.sol";

import {Test, console} from "forge-std/Test.sol";


contract Rewarder is Test {

    uint80 BASE_UNIT = 10 ** 8;
    uint256 TEN_POW_10 = 10 ** 10;
    GeniRewarder geniRewarder;
    address trader1 = address(0x111);
    address trader2 = address(0x222);

    function setUp() public {
        // GeniDex
        GeniDex dex = GeniDexHelper.deploy();
        console.log('GeniDex:', address(dex));

        // GeniToken
        GeniToken geniToken = GeniTokenHelper.deployGeniToken();
        console.log('GeniToken:', address(geniToken));

        // GeniRewarder
        geniRewarder = GeniRewarderHelper.deploy(address(geniToken), address(dex));
        console.log('GeniRewarder:', address(geniRewarder));

        // setGeniRewarder
        dex.setGeniRewarder(address(geniRewarder));

        // contribute
        uint256 amount = 21_024_000 * BASE_UNIT;
        geniToken.approve(address(geniRewarder), amount*TEN_POW_10);
        geniRewarder.contribute(amount);

        // quoteToken
        TestToken quoteToken =  new TestToken('USDT', 'USDT', 1_000_000_000*10**6, 6);
        dex.listToken(address(quoteToken), 0, 0, 0, true, true, '', 0);

        // baseToken
        TestToken baseToken =   new TestToken('OP', 'OP', 1_000_000_000*10**18, 18);
        dex.listToken(address(baseToken), 0, 0, 0, false, true, '', 0);

        //addMarket
        dex.addMarket(address(baseToken), address(quoteToken));
        uint256 marketId = 1;
        dex.updateMarketIsRewardable(marketId, true);

        // trader1: mint, approve, deposit, placeBuyOrder
        vm.startPrank(trader1);
        uint256[] memory sellOrderIDs;
        quoteToken.mint();
        uint256 quoteAmount = 100;
        quoteAmount = quoteAmount + quoteAmount / 1000;
        quoteToken.approve(address(dex), quoteAmount*10**6);
        dex.depositToken(address(quoteToken), quoteAmount*BASE_UNIT);
        dex.placeBuyOrder(marketId, 1*BASE_UNIT, 10*BASE_UNIT, 0, sellOrderIDs, address(0));
        vm.stopPrank();

        // trader2: mint, approve, deposit, placeBuyOrder
        vm.startPrank(trader2);
        uint256[] memory buyOrderIDs = new uint256[](1);
        buyOrderIDs[0] = 0;
        baseToken.mint();
        uint256 baseAmount = 100;
        baseToken.approve(address(dex), baseAmount*10**18);
        dex.depositToken(address(baseToken), baseAmount*BASE_UNIT);
        dex.placeSellOrder(marketId, 1*BASE_UNIT, 10*BASE_UNIT, 0, buyOrderIDs, address(trader1));
    }

    function printUserRewardInfo(string memory title, address trader) internal view{
        (uint256 tradingPoints,
        uint256 refPoints,
        uint256 estimatedReward,
        uint256 totalClaimed,
        uint256 pointsPerGENI) = geniRewarder.getUserRewardInfo(address(trader));

        console.log('\n', title);
        console.log('tradingPoints', tradingPoints/BASE_UNIT);
        console.log('refPoints', refPoints/BASE_UNIT);
        console.log('estimatedReward', estimatedReward/BASE_UNIT);
        console.log('totalClaimed', totalClaimed/BASE_UNIT);
        console.log('pointsPerGENI', pointsPerGENI/BASE_UNIT);
        // console.log(userPoints, estimatedReward);
    }

    function trader2Claim() public {
        vm.warp(block.timestamp + 61);
        vm.startPrank(trader2);
        printUserRewardInfo('trader2', trader2);
        geniRewarder.claim(10*BASE_UNIT);
        printUserRewardInfo('trader2', trader2);
        vm.stopPrank();
        // counter.increment();
        // assertEq(counter.number(), 1);
    }

    function test_Claim2() public {
        trader2Claim();
        vm.warp(block.timestamp + 61);
        vm.startPrank(trader1);
        printUserRewardInfo('trader1', trader1);
        geniRewarder.redeemReferralPoints(3*BASE_UNIT);
        printUserRewardInfo('trader1', trader1);
        vm.stopPrank();
        // counter.increment();
        // assertEq(counter.number(), 1);
    }

    // function testFuzz_SetNumber(uint256 x) public {
    //     // counter.setNumber(x);
    //     // assertEq(counter.number(), x);
    // }
}
