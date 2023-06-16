pragma solidity 0.8.17;

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
import "contracts/Token.sol";
import "contracts/Option.sol";
import "contracts/TokenLibrary.sol";
import "contracts/Voter.sol";
import "contracts/VeArtProxy.sol";
import "contracts/VotingEscrow.sol";
import "contracts/TokenGovernor.sol";
import "utils/TestOwner.sol";
import "utils/TestStakingRewards.sol";
import "utils/TestToken.sol";
import "utils/TestVoter.sol";
import "utils/TestVotingEscrow.sol";
import "utils/TestWETH.sol";
import "contracts/oracles/UniswapV2Oracle.sol";
contract Emission is Test {
    TestWETH WETH;
    MockERC20 DAI;
    uint TOKEN_100 = 100 * 1e18;
    Token token;
    Option oToken;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    PairFactory pairFactory;
    Router2 router;
    VeArtProxy artProxy;
    VotingEscrow escrow;
    RewardsDistributor distributor;
    Voter voter;
    Minter minter;
    TokenGovernor governor;
    Pair pool_eth_dai;
    Pair pool_eth_token;
    address[] whitelist;
    Gauge gauge_eth_token;
    address tokenEth;
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
        token = new Token();

        vm.warp(1686178415);
        token.approve(address(router), tokenAmount);
        token.mint(address(this), tokenAmount);
        router.addLiquidityETH{value: wethAmount}(address(token), false, tokenAmount, 0, 0, address(this), block.timestamp);
        tokenEth = router.pairFor(address(token), address(WETH), false);
        uint lpBalance = Pair(tokenEth).balanceOf(address(this));
        assertGt(lpBalance, 0);

        oracle = new UniswapV2Oracle(tokenEth, address(WETH));
        oToken = new Option();

        lp = Pair(factory.createPair(address(token), address(WETH), false));
        escrow = new VotingEscrow(tokenEth, address(oToken), address(artProxy));
        distributor = new RewardsDistributor(address(escrow));
        voter = new Voter(address(escrow), address(pairFactory), address(gaugeFactory), address(bribeFactory));
        minter = new Minter(address(token), address(voter), address(escrow), address(distributor));
        governor = new TokenGovernor(escrow);

        // allow minter to mint options:
        oToken.initialize(address(minter), ERC20(WETH), IToken(token), IOracle(oracle), treasure);

        // ---
        oToken.initialMint(address(this), tokenAmount);
        token.addMinter(address(minter));
        escrow.setVoter(address(voter));
        escrow.setTeam(address(this));
        voter.setGovernor(address(this));
        voter.setEmergencyCouncil(address(this));
        distributor.setDepositor(address(minter));
        governor.setTeam(address(this));


        whitelist.push(address(token));
        whitelist.push(address(DAI));
        voter.initialize(whitelist, address(minter));
        minter.setTeam(address(this));

        // ---
        DAI.mint(address(this), TOKEN_100);
        DAI.approve(address(router), TOKEN_100);

        token.mint(address(this), TOKEN_100);
        token.approve(address(router), TOKEN_100);

        router.addLiquidityETH{value : TOKEN_100}(address(DAI), false, TOKEN_100, 0, 0, address(this), block.timestamp);
        router.addLiquidityETH{value : TOKEN_100}(address(token), false, TOKEN_100, 0, 0, address(this), block.timestamp);

        pool_eth_dai = Pair( pairFactory.getPair(address(WETH),address(DAI), false) );
        pool_eth_token = Pair( pairFactory.getPair(address(WETH),address(token), false) );

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
        InternalBribe bribe = InternalBribe(gauge_eth_token.internal_bribe());
        return bribe.getEpochStart(block.timestamp);
    }
    function testExec() public {
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);

        gauge_eth_token = Gauge(voter.createGauge(address(pool_eth_token)));
        vm.roll(block.number + 1);
        uint duration = 1 days * 365;
        uint deposit = pool_eth_token.balanceOf(address(this));
        uint depositHalf = deposit / 2;
        //console2.log('lp deposited:', deposit/1e18);

        // create 50% lp lock:
        pool_eth_token.approve(address(escrow), depositHalf);
        tokenId = escrow.create_lock(depositHalf, duration);
        // do a 50% gauge deposit:
        pool_eth_token.approve(address(gauge_eth_token), depositHalf);
        gauge_eth_token.deposit(depositHalf, tokenId);


        address[] memory pools = new address[](1);
        pools[0] = address(pool_eth_token);
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
        path1[0] = Router.route(address(WETH), address(token), false);

        Router.route[] memory path2 = new Router.route[](1);
        path2[0] = Router.route(address(token), address(WETH), false);

        for(uint i = 0; i < 10; i++){
            uint balanceBefore = token.balanceOf(address(this));
            router.swapExactETHForTokens{value: amount}(0, path1, address(this), block.timestamp);
            uint balanceAfter = token.balanceOf(address(this));
            uint tokensBought = balanceAfter - balanceBefore;

            token.approve(address(router), tokensBought);
            router.swapExactTokensForETH(tokensBought, 0, path2, address(this), block.timestamp);
        }

        //console2.log('---------------------- epoch:', getEpoch());
        //console2.log('option balance before distro:', oToken.balanceOf(address(this))/1e18);
        vm.warp(block.timestamp + (86400 * 7)+ 1 );
        vm.roll(block.number + 1);
        voter.distro();

        if( index == 0 ) return;

        address[] memory tokens = new address[](1);
        tokens[0] = address(oToken);

        uint tokenBalanceBefore = oToken.balanceOf(address(this));

        gauge_eth_token.getReward(address(this), tokens);

        uint tokenEarned = oToken.balanceOf(address(this)) - tokenBalanceBefore;

        assertGt(tokenEarned, 0);

        // claimFees
        IERC20 pair0 = IERC20(pool_eth_token.token0());
        IERC20 pair1 = IERC20(pool_eth_token.token1());

        address internalBribeAddress = gauge_eth_token.internal_bribe();
        //address externalBribeAddress = gauge_eth_token.external_bribe();

        InternalBribe internalBribe = InternalBribe(internalBribeAddress);
        //ExternalBribe externalBribe = ExternalBribe(externalBribeAddress);

        uint fee0EarnedInternal = internalBribe.earned(address(pair0), tokenId);
        uint fee1EarnedInternal = internalBribe.earned(address(pair1), tokenId);

        assertGt(fee0EarnedInternal, 0);
        assertGt(fee1EarnedInternal, 0);

    }
}
