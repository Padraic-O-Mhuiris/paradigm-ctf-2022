// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "forge-std/console2.sol";
import "./MasterChefHelper.sol";

interface WETH9 is ERC20Like {
    function deposit() external payable;
}

contract Setup {
    WETH9 public constant weth = WETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    MasterChefHelper public immutable mcHelper;

    constructor() payable {
        mcHelper = new MasterChefHelper();

        console2.log("SETUP ETH BALANCE", address(this).balance);
        console2.log("SETUP WETH BALANCE", weth.balanceOf(address(this)));
        console2.log("MC WETH BALANCE", weth.balanceOf(address(mcHelper)));
        weth.deposit{value: 10 ether}();
        console2.log("SETUP ETH BALANCE", address(this).balance);
        console2.log("SETUP WETH BALANCE", weth.balanceOf(address(this)));
        console2.log("MC WETH BALANCE", weth.balanceOf(address(mcHelper)));
        weth.transfer(address(mcHelper), 10 ether); // whoops
        console2.log("SETUP ETH BALANCE", address(this).balance);
        console2.log("SETUP WETH BALANCE", weth.balanceOf(address(this)));
        console2.log("MC WETH BALANCE", weth.balanceOf(address(mcHelper)));
    }

    function isSolved() external view returns (bool) {
        return weth.balanceOf(address(mcHelper)) == 0;
    }
}
