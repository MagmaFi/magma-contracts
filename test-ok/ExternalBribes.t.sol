pragma solidity 0.8.17;

import './BaseTest.sol';

contract ExternalBribesTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;
    Gauge gauge;
    InternalBribe bribe;
    ExternalBribe xbribe;

    function setUp() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        deployOptionsToken();

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2e25;
        amounts[1] = 1e25;
        amounts[2] = 1e25;
        mintOption(owners, amounts);
        mintLR(owners, amounts);
        VeArtProxy artProxy = new VeArtProxy();

        lp = Pair(factory.createPair(address(token), address(WETH), false));
        escrow = new VotingEscrow(address(lp),address(oToken), address(artProxy));
        deployPairFactoryAndRouter();
        deployPairWithOwner(address(owner));

        // deployVoter()
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(address(escrow), address(factory), address(gaugeFactory), address(bribeFactory));

        escrow.setVoter(address(voter));

        // deployMinter()
        distributor = new RewardsDistributor(address(escrow));
        minter = new Minter(address(voter), address(escrow), address(distributor));
        distributor.setDepositor(address(minter));
        oToken.addMinter(address(minter));
        address[] memory tokens = new address[](5);
        tokens[0] = address(USDC);
        tokens[1] = address(FRAX);
        tokens[2] = address(DAI);
        tokens[3] = address(oToken);
        tokens[4] = address(LR);
        voter.initialize(tokens, address(minter));

        address[] memory claimants = new address[](0);
        uint[] memory amounts1 = new uint[](0);
        minter.initialize(claimants, amounts1);

        // USDC - FRAX stable
        gauge = Gauge(voter.createGauge(address(pair)));
        bribe = InternalBribe(gauge.internal_bribe());
        xbribe = ExternalBribe(gauge.external_bribe());

        // create LP tokens by adding liquidity to lock:



        // ve
        uint lpAmount = lpAdd(address(this), TOKEN_1, TOKEN_1);
        vm.deal(address(this), TOKEN_1);
        lp.approve(address(escrow), lpAmount);
        escrow.create_lock(TOKEN_1, 4 * 365 * 86400);

        token.addMinter(address(owner2));
        vm.startPrank(address(owner2));
        vm.deal(address(owner2), TOKEN_1);
        lpAmount = lpAdd(address(owner2), TOKEN_1, TOKEN_1);
        lp.approve(address(escrow), lpAmount);
        escrow.create_lock(TOKEN_1, 4 * 365 * 86400);
        vm.warp(block.timestamp + 1);
        vm.stopPrank();

    }

    function testCanClaimExternalBribe() public {

        // fwd half a week
        vm.warp(block.timestamp + 1 weeks / 2);

        // create a bribe
        LR.approve(address(xbribe), TOKEN_1);
        xbribe.notifyRewardAmount(address(LR), TOKEN_1);
        assertEq(LR.balanceOf(address(xbribe)), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // cannot claim
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        xbribe.getRewardForOwner(1, rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, 0);

        // fwd half a week
        // as we set the oracle timestamp, we forward 1 week now.
        vm.warp(block.timestamp + 1 weeks);

        // deliver bribe
        pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        xbribe.getRewardForOwner(1, rewards);
        post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1);

    }

    function testCanClaimExternalBribeProRata() public {

        // fwd half a week
        vm.warp(block.timestamp + 1 weeks / 2);

        // create a bribe
        LR.approve(address(xbribe), TOKEN_1);
        xbribe.notifyRewardAmount(address(LR), TOKEN_1);
        assertEq(LR.balanceOf(address(xbribe)), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        vm.startPrank(address(owner2));
        voter.vote(2, pools, weights);
        vm.stopPrank();

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // fwd half a week
        // as we set the oracle timestamp, we forward 1 week now.
        vm.warp(block.timestamp + 1 weeks );

        // deliver bribe
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        xbribe.getRewardForOwner(1, rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertEq(post - pre, TOKEN_1 / 2);

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        xbribe.getRewardForOwner(2, rewards);
        post = LR.balanceOf(address(owner2));
        assertEq(post - pre, TOKEN_1 / 2);

    }

    function testCanClaimExternalBribeStaggered() public {


        // fwd half a week
        vm.warp(block.timestamp + 1 weeks / 2);

        // create a bribe
        LR.approve(address(xbribe), TOKEN_1);
        xbribe.notifyRewardAmount(address(LR), TOKEN_1);
        assertEq(LR.balanceOf(address(xbribe)), TOKEN_1);

        // vote
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;
        voter.vote(1, pools, weights);

        // vote delayed
        vm.warp(block.timestamp + 1 days);
        vm.startPrank(address(owner2));
        voter.vote(2, pools, weights);
        vm.stopPrank();

        // rewards
        address[] memory rewards = new address[](1);
        rewards[0] = address(LR);

        // fwd
        vm.warp(block.timestamp + 1 weeks / 2);

        // deliver bribe
        uint256 pre = LR.balanceOf(address(owner));
        vm.prank(address(voter));
        xbribe.getRewardForOwner(1, rewards);
        uint256 post = LR.balanceOf(address(owner));
        assertGt(post - pre, TOKEN_1 / 2); // 500172176312657261
        uint256 diff = post - pre;

        pre = LR.balanceOf(address(owner2));
        vm.prank(address(voter));
        xbribe.getRewardForOwner(2, rewards);
        post = LR.balanceOf(address(owner2));
        assertLt(post - pre, TOKEN_1 / 2); // 499827823687342738
        uint256 diff2 = post - pre;

        assertEq(diff + diff2, TOKEN_1 - 1); // -1 for rounding

    }
}
