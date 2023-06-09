// 1:1 with Hardhat test
pragma solidity 0.8.17;

import "./BaseTest.sol";

contract OptionVotingTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;
    TestOwner team;

    function setUp() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amountsOption = new uint256[](2);
        amountsOption[0] = 1e25;
        amountsOption[1] = 1e25;
        mintOption(owners, amountsOption);
        team = new TestOwner();
        VeArtProxy artProxy = new VeArtProxy();
        deployTokenEthPair(1e18, 1e18);
        escrow = new VotingEscrow(address(lp), address(oToken), address(artProxy));
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(
            address(escrow),
            address(factory),
            address(gaugeFactory),
            address(bribeFactory)
        );

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(oToken);
        voter.initialize(tokens, address(owner));

        uint lpAmount = lpAdd(address(this), 100 * TOKEN_1, 100 * TOKEN_1);

        lp.approve(address(escrow), lpAmount);
        escrow.create_lock(lpAmount, 4 * 365 * 86400);

        distributor = new RewardsDistributor(address(escrow));
        escrow.setVoter(address(voter));

        minter = new Minter(address(token), address(voter), address(escrow), address(distributor));
        distributor.setDepositor(address(minter));
        oToken.addMinter(address(minter));

        oToken.approve(address(router), TOKEN_1);
        FRAX.approve(address(router), TOKEN_1);
        router.addLiquidity(
            address(FRAX),
            address(oToken),
            false,
            TOKEN_1,
            TOKEN_1,
            0,
            0,
            address(owner),
            block.timestamp
        );


        address pair = router.pairFor(address(FRAX), address(oToken), false);

        oToken.approve(address(voter), 5 * TOKEN_100K);
        voter.createGauge(pair);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385, "@1");
        assertEq(lp.balanceOf(address(escrow)), lpAmount, "@2");

        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);

        address[] memory claimants = new address[](1);
        claimants[0] = address(owner);
        uint256[] memory amountsToMint = new uint256[](1);
        amountsToMint[0] = TOKEN_1M;
        minter.initialize(claimants, amountsToMint);
        // initialize does not mint veNFT and does not mint tokens to minter anymore:
        //assertEq(escrow.ownerOf(2), address(owner), "@3");
        //assertEq(escrow.ownerOf(3), address(0), "@4");
        vm.roll(block.number + 1);
        //assertEq(oToken.balanceOf(address(minter)), 838_000 * 1e18, "@5");

        uint256 before = oToken.balanceOf(address(owner));
        minter.update_period(); // initial period week 1
        uint256 after_ = oToken.balanceOf(address(owner));
        assertEq(minter.weekly(), 1_838_000 * 1e18, "@6");
        assertEq(after_ - before, 0, "@6");
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        before = oToken.balanceOf(address(owner));
        minter.update_period(); // initial period week 2
        after_ = oToken.balanceOf(address(owner));
        assertLt(minter.weekly(), 1_838_000 * 1e18, "@8"); // <15M for week shift

    }

    // Note: _vote and _reset are not included in one-vote-per-epoch
    // Only vote() and reset() should be constrained as they must be called by the owner
    // poke() can be called by anyone anytime to "refresh" an outdated vote state



    function testCannotChangeVoteOrResetInSameEpoch() public {
        // vote
        vm.warp(block.timestamp + 1 weeks);
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);

        // fwd half epoch
        vm.warp(block.timestamp + 1 weeks / 2);

        // try voting again and fail
        pools[0] = address(pair2);
        vm.expectRevert(abi.encodePacked("TOKEN_ALREADY_VOTED_THIS_EPOCH"));
        voter.vote(1, pools, weights);

        // try resetting and fail
        vm.expectRevert(abi.encodePacked("TOKEN_ALREADY_VOTED_THIS_EPOCH"));
        voter.reset(1);
    }

    function testCanChangeVoteOrResetInNextEpoch() public {
        // vote
        vm.warp(block.timestamp + 1 weeks);
        address[] memory pools = new address[](1);
        pools[0] = address(pair);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;

        voter.vote(1, pools, weights);

        // fwd whole epoch
        vm.warp(block.timestamp + 1 weeks);

        // try voting again and fail
        pools[0] = address(pair2);
        voter.vote(1, pools, weights);

        // fwd whole epoch
        vm.warp(block.timestamp + 1 weeks);

        voter.reset(1);
    }

}
