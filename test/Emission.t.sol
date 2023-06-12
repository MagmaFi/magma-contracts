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
import "contracts/options-token/OptionsToken.sol";
import "contracts/MagmaLibrary.sol";
import "contracts/Voter.sol";
import "contracts/VeArtProxy.sol";
import "contracts/VotingEscrow.sol";
import "contracts/MagmaGovernor.sol";
import "utils/TestOwner.sol";
import "utils/TestStakingRewards.sol";
import "utils/TestToken.sol";
import "utils/TestVoter.sol";
import "utils/TestVotingEscrow.sol";
import "utils/TestWETH.sol";
import "contracts/options-token/oracles/UniswapV2Oracle.sol";
contract Emission is Test {
    TestWETH WETH;
    MockERC20 DAI;
    uint TOKEN_100 = 100 * 1e18;
    Magma magma;
    OptionsToken oMagma;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    PairFactory pairFactory;
    Router2 router;
    VeArtProxy artProxy;
    VotingEscrow escrow;
    RewardsDistributor distributor;
    Voter voter;
    Minter minter;
    MagmaGovernor governor;
    Pair pool_eth_dai;
    Pair pool_eth_magma;
    address[] whitelist;
    Gauge gauge_eth_magma;
    address magmaEth;
    UniswapV2Oracle oracle;
    uint wethAmount = 100e18;
    uint tokenAmount = 100e18;
    address treasure;
    address partner;
    address team;
    uint tokenId;
    function setUp() public {
        treasure = makeAddr("treasure");
        partner = makeAddr("partner");
        team = makeAddr("team");
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        pairFactory = new PairFactory();
        WETH = new TestWETH();
        DAI = new MockERC20("DAI", "DAI", 18);
        router = new Router2(address(pairFactory), address(WETH));
        artProxy = new VeArtProxy();
        magma = new Magma();

        vm.warp(1686178415);
        magma.approve(address(router), tokenAmount);
        magma.mint(address(this), tokenAmount);
        router.addLiquidityETH{value: wethAmount}(address(magma), false, tokenAmount, 0, 0, address(this), block.timestamp);
        magmaEth = router.pairFor(address(magma), address(WETH), false);
        uint lpBalance = Pair(magmaEth).balanceOf(address(this));
        assertGt(lpBalance, 0);

        oracle = new UniswapV2Oracle(magmaEth, address(WETH));
        oMagma = new OptionsToken("OPT","Option", address(this), ERC20(WETH), IMagma(magma), IOracle(oracle), treasure);
        
        escrow = new VotingEscrow(magmaEth, address(oMagma), address(artProxy));
        distributor = new RewardsDistributor(address(escrow));
        voter = new Voter(address(escrow), address(pairFactory), address(gaugeFactory), address(bribeFactory));
        minter = new Minter(address(voter), address(escrow), address(distributor));
        governor = new MagmaGovernor(escrow);
        // allow minter to mint options:
        oMagma.setMinter(address(minter));
        // ---
        magma.initialMint(address(this), tokenAmount);
        magma.setMinter(address(minter));
        escrow.setVoter(address(voter));
        escrow.setTeam(address(this));
        voter.setGovernor(address(this));
        voter.setEmergencyCouncil(address(this));
        distributor.setDepositor(address(minter));
        governor.setTeam(address(this));


        whitelist.push(address(magma));
        whitelist.push(address(DAI));
        voter.initialize(whitelist, address(minter));
        //minter.initialize([], [], 0);
        minter.setTeam(address(this));

        // ---
        DAI.mint(address(this), TOKEN_100);
        DAI.approve(address(router), TOKEN_100);
        magma.approve(address(router), TOKEN_100);

        router.addLiquidityETH{value : TOKEN_100}(address(DAI), false, TOKEN_100, 0, 0, address(this), block.timestamp);
        router.addLiquidityETH{value : TOKEN_100}(address(magma), false, TOKEN_100, 0, 0, address(this), block.timestamp);

        pool_eth_dai = Pair( pairFactory.getPair(address(WETH),address(DAI), false) );
        pool_eth_magma = Pair( pairFactory.getPair(address(WETH),address(magma), false) );

        address[] memory emptyAddresses = new address[](1);
        emptyAddresses[0] = partner;
        uint[] memory emptyAmounts = new uint[](1);
        emptyAmounts[0] = 100e18;
        minter.initialize(emptyAddresses, emptyAmounts);
        minter.setTeam(team);
    }
    fallback() external payable {}
    receive() external payable {}
    function getEpoch() public view returns(uint){
        InternalBribe bribe = InternalBribe(gauge_eth_magma.internal_bribe());
        return bribe.getEpochStart(block.timestamp);
    }
    function testExec() public {
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);

        gauge_eth_magma = Gauge(voter.createGauge(address(pool_eth_magma)));
        vm.roll(block.number + 1);
        uint duration = 1 days * 365;
        uint deposit = pool_eth_magma.balanceOf(address(this));
        uint depositHalf = deposit / 2;
        //console2.log('lp deposited:', deposit/1e18);

        // create 50% lp lock:
        pool_eth_magma.approve(address(escrow), depositHalf);
        tokenId = escrow.create_lock(depositHalf, duration);
        // do a 50% gauge deposit:
        pool_eth_magma.approve(address(gauge_eth_magma), depositHalf);
        gauge_eth_magma.deposit(depositHalf, tokenId);


        address[] memory pools = new address[](1);
        pools[0] = address(pool_eth_magma);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;

        vm.warp(block.timestamp + 86400 * 3);
        vm.roll(block.number + 1);
        voter.vote(tokenId, pools, weights);

        distro(0);
        distro(1);
        distro(2);
    }
    function distro(uint index) public{

        // do some swaps:
        uint256 amount = 1e18;
        Router.route[] memory path1 = new Router.route[](1);
            path1[0] = Router.route(address(WETH), address(magma), false);

        Router.route[] memory path2 = new Router.route[](1);
           path2[0] = Router.route(address(magma), address(WETH), false);

        for(uint i = 0; i < 10; i++){
            uint balanceBefore = magma.balanceOf(address(this));
            router.swapExactETHForTokens{value: amount}(0, path1, address(this), block.timestamp);
            uint balanceAfter = magma.balanceOf(address(this));
            uint tokensBought = balanceAfter - balanceBefore;

            magma.approve(address(router), tokensBought);
            router.swapExactTokensForETH(tokensBought, 0, path2, address(this), block.timestamp);
        }

        //console2.log('---------------------- epoch:', getEpoch());
        //console2.log('option balance before distro:', oMagma.balanceOf(address(this))/1e18);
        vm.warp(block.timestamp + (86400 * 7)+ 1 );
        vm.roll(block.number + 1);
        voter.distro();

        if( index == 0 ) return;

        address[] memory tokens = new address[](1);
            tokens[0] = address(oMagma);

        uint magmaBalanceBefore = oMagma.balanceOf(address(this));

        gauge_eth_magma.getReward(address(this), tokens);

        uint magmaEarned = oMagma.balanceOf(address(this)) - magmaBalanceBefore;

        assertGt(magmaEarned, 0);

        // claimFees
        IERC20 pair0 = IERC20(pool_eth_magma.token0());
        IERC20 pair1 = IERC20(pool_eth_magma.token1());

        address internalBribeAddress = gauge_eth_magma.internal_bribe();
        //address externalBribeAddress = gauge_eth_magma.external_bribe();

        InternalBribe internalBribe = InternalBribe(internalBribeAddress);
        //ExternalBribe externalBribe = ExternalBribe(externalBribeAddress);

        uint fee0EarnedInternal = internalBribe.earned(address(pair0), tokenId);
        uint fee1EarnedInternal = internalBribe.earned(address(pair1), tokenId);

        assertGt(fee0EarnedInternal, 0);
        assertGt(fee1EarnedInternal, 0);

    }
}
