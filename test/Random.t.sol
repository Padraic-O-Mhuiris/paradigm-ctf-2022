// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {Setup, Random} from "../src/random/Setup.sol";

contract ExploitRandom is Test {
    Setup s;
    Random random;

    function setUp() public {
        s = new Setup();
        random = s.random();
    }

    function test__exploit() public {
        random.solve(4);
        assertTrue(s.isSolved());
    }
}
