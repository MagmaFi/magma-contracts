pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "solmate/src/test/utils/mocks/MockERC20.sol";
import "contracts/factories/BribeFactory.sol";
import "contracts/factories/GaugeFactory.sol";
import "contracts/factories/PairFactory.sol";
import "contracts/redeem/MerkleClaim.sol";
import "contracts/InternalBribe.sol";
import "contracts/ExternalBribe.sol";
import "contracts/Gauge.sol";
import "contracts/Minter.sol";
import "contracts/Pair.sol";
import "contracts/PairFees.sol";
import "contracts/RewardsDistributor.sol";
import "contracts/Router.sol";
import "contracts/Router2.sol";
import "contracts/Magma.sol";
import "contracts/MagmaLibrary.sol";
import "contracts/Voter.sol";
import "contracts/VeArtProxy.sol";
import "contracts/VotingEscrow.sol";
import "utils/TestOwner.sol";
import "utils/TestStakingRewards.sol";
import "utils/TestToken.sol";
import "utils/TestVoter.sol";
import "utils/TestVotingEscrow.sol";
import "utils/TestWETH.sol";

import "contracts/options-token/OptionsToken.sol";
import "contracts/options-token/oracles/UniswapV2Oracle.sol";

abstract contract BaseTest is Test, TestOwner {
    uint256 constant USDC_1 = 1e6;
    uint256 constant USDC_100K = 1e11; // 1e5 = 100K tokens with 6 decimals
    uint256 constant USDC_1M = 1e12;
    uint256 constant TOKEN_1 = 1e18;
    uint256 constant TOKEN_100K = 1e23; // 1e5 = 100K tokens with 18 decimals
    uint256 constant TOKEN_1M = 1e24; // 1e6 = 1M tokens with 18 decimals
    uint256 constant TOKEN_100M = 1e26; // 1e8 = 100M tokens with 18 decimals
    uint256 constant TOKEN_10B = 1e28; // 1e10 = 10B tokens with 18 decimals
    uint256 constant PAIR_1 = 1e9;

    TestOwner owner;
    TestOwner owner2;
    TestOwner owner3;
    address[] owners;
    MockERC20 USDC;
    MockERC20 FRAX;
    MockERC20 DAI;
    TestWETH WETH; // Mock WETH token
    Magma MAGMA;
    MockERC20 WEVE;
    MockERC20 LR; // late reward
    TestToken stake; // MockERC20 with claimFees() function that returns (0,0)
    PairFactory factory;
    Router router;
    Router2 router2;
    MagmaLibrary lib;
    Pair pair;
    Pair pair2;
    Pair pair3;

    OptionsToken optionsToken;
    UniswapV2Oracle oracle;

    function deployOwners() public {
        owner = TestOwner(address(this));
        owner2 = new TestOwner();
        owner3 = new TestOwner();
        owners = new address[](3);
        owners[0] = address(owner);
        owners[1] = address(owner2);
        owners[2] = address(owner3);
    }

    function deployCoins() public {
        USDC = new MockERC20("USDC", "USDC", 6);
        FRAX = new MockERC20("FRAX", "FRAX", 18);
        DAI = new MockERC20("DAI", "DAI", 18);
        MAGMA = new Magma();
        WEVE = new MockERC20("WEVE", "WEVE", 18);
        LR = new MockERC20("LR", "LR", 18);
        WETH = new TestWETH();
        stake = new TestToken("stake", "stake", 18, address(owner));
    }

    function mintStables() public {
        for (uint256 i = 0; i < owners.length; i++) {
            USDC.mint(owners[i], 1e12 * USDC_1);
            FRAX.mint(owners[i], 1e12 * TOKEN_1);
            DAI.mint(owners[i], 1e12 * TOKEN_1);
        }
    }

    function mintMagma(address[] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _amounts.length; i++) {
            MAGMA.mint(_accounts[i], _amounts[i]);
        }
    }

    function mintLR(address[] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _accounts.length; i++) {
            LR.mint(_accounts[i], _amounts[i]);
        }
    }

    function mintStake(address[] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _accounts.length; i++) {
            stake.mint(_accounts[i], _amounts[i]);
        }
    }

    function mintWETH(address[] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _accounts.length; i++) {
            WETH.mint(_accounts[i], _amounts[i]);
        }
    }

    function dealETH(address [] memory _accounts, uint256[] memory _amounts) public {
        for (uint256 i = 0; i < _accounts.length; i++) {
            vm.deal(_accounts[i], _amounts[i]);
        }
    }

    function deployPairFactoryAndRouter() public {
        factory = new PairFactory();
        assertEq(factory.allPairsLength(), 0);
        factory.setFee(true, 1); // set fee back to 0.01% for old tests
        factory.setFee(false, 1);
        router = new Router(address(factory), address(WETH));
        router2 = new Router2(address(factory), address(WETH));
        assertEq(router.factory(), address(factory));
        lib = new MagmaLibrary(address(router));
    }
    function deployPair(uint tokenAmount, uint wethAmount) public returns(address) {
        deployPairFactoryAndRouter();
        MAGMA.approve(address(router), tokenAmount);
        router.addLiquidityETH{value: wethAmount}(address(MAGMA), false, tokenAmount, 0, 0, address(this), block.timestamp);
        pair = Pair(router.pairFor(address(MAGMA), address(WETH), false));
        return address(pair);
    }
    function deployPairWithOwner(address _owner) public {
        TestOwner(_owner).approve(address(FRAX), address(router), TOKEN_1);
        TestOwner(_owner).approve(address(USDC), address(router), USDC_1);
        TestOwner(_owner).addLiquidity(payable(address(router)), address(FRAX), address(USDC), true, TOKEN_1, USDC_1, 0, 0, address(owner), block.timestamp);
        TestOwner(_owner).approve(address(FRAX), address(router), TOKEN_1);
        TestOwner(_owner).approve(address(USDC), address(router), USDC_1);
        TestOwner(_owner).addLiquidity(payable(address(router)), address(FRAX), address(USDC), false, TOKEN_1, USDC_1, 0, 0, address(owner), block.timestamp);
        TestOwner(_owner).approve(address(FRAX), address(router), TOKEN_1);
        TestOwner(_owner).approve(address(DAI), address(router), TOKEN_1);
        TestOwner(_owner).addLiquidity(payable(address(router)), address(FRAX), address(DAI), true, TOKEN_1, TOKEN_1, 0, 0, address(owner), block.timestamp);

        assertEq(factory.allPairsLength(), 3);

        address create2address = router.pairFor(address(FRAX), address(USDC), true);
        address address1 = factory.getPair(address(FRAX), address(USDC), true);
        pair = Pair(address1);
        address address2 = factory.getPair(address(FRAX), address(USDC), false);
        pair2 = Pair(address2);
        address address3 = factory.getPair(address(FRAX), address(DAI), true);
        pair3 = Pair(address3);
        assertEq(address(pair), create2address);
        assertGt(lib.getAmountOut(USDC_1, address(USDC), address(FRAX), true), 0);
    }

    function mintPairFraxUsdcWithOwner(address _owner) public {
        TestOwner(_owner).transfer(address(USDC), address(pair), USDC_1);
        TestOwner(_owner).transfer(address(FRAX), address(pair), TOKEN_1);
        TestOwner(_owner).mint(address(pair), _owner);
    }

    function deployOracleWithDefaultPair(uint magmaAmount, uint ethAmount) public returns(address) {
        if( address(USDC) == address(0) ) {
            deployCoins();
            mintStables();
        }
        if( MAGMA.balanceOf(address(this)) == 0 ) {
            address[] memory _accounts = new address[](1);
            _accounts[0] = address(this);
            uint256[] memory _amounts = new uint256[](1);
            _amounts[0] = 100_000 * TOKEN_1;
            mintMagma(_accounts, _amounts);
            mintWETH(_accounts, _amounts);
            dealETH(_accounts, _amounts);
        }
        deployPairFactoryAndRouter();
        address magmaEth = deployPair(magmaAmount, ethAmount);
        oracle = new UniswapV2Oracle(magmaEth, address(WETH));
        return address(oracle);
    }

    function deployOptionsToken() public {
        if( address(oracle) == address(0) )
            deployOracleWithDefaultPair(100e18, 100e18);
        // prevent timestamp calculation problem in the oracle:
        vm.warp(1686178415);
        optionsToken = new OptionsToken("OPT","Option", address(this), ERC20(WETH), IMagma(MAGMA), IOracle(oracle), address(owner));
    }

    receive() external payable {}
}
