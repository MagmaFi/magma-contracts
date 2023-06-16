// 1:1 with Hardhat test
pragma solidity 0.8.17;

import './BaseTest.sol';

contract MinterTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    RewardsDistributor distributor;
    Minter minter;

    function deployBase() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e25;
        mintOption(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();
        deployTokenEthPair(0, 0);
        escrow = new VotingEscrow(address(lp),address(oToken), address(artProxy));

        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(address(escrow), address(factory), address(gaugeFactory), address(bribeFactory));

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);
        tokens[1] = address(oToken);
        voter.initialize(tokens, address(owner));

        uint amount = lpAdd(address(this), 100 * TOKEN_1, 100 * TOKEN_1);
        lp.approve(address(escrow), amount);
        escrow.create_lock(amount, 4 * 365 * 86400);
        distributor = new RewardsDistributor(address(escrow));
        escrow.setVoter(address(voter));

        minter = new Minter(address(voter), address(escrow), address(distributor));
        distributor.setDepositor(address(minter));
        oToken.addMinter(address(minter));

        oToken.approve(address(router), TOKEN_1);
        FRAX.approve(address(router), TOKEN_1);
        router.addLiquidity(address(FRAX), address(oToken), false, TOKEN_1, TOKEN_1, 0, 0, address(owner), block.timestamp);

        address pair = router.pairFor(address(FRAX), address(oToken), false);

        oToken.approve(address(voter), 5 * TOKEN_100K);
        voter.createGauge(pair);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(lp.balanceOf(address(escrow)), amount);

        address[] memory pools = new address[](1);
        pools[0] = pair;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        voter.vote(1, pools, weights);
    }

    function initializeVotingEscrow() public {
        deployBase();
        // we don't create veNFT anymore.
        address[] memory claimants = new address[](1);
        claimants[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOKEN_1M;
        uint balanceBefore = oToken.balanceOf(address(owner));
        minter.initialize(claimants, amounts);
        assertEq(oToken.balanceOf(address(owner)), TOKEN_1M + balanceBefore );
        vm.roll(block.number + 1);
    }

    function testMinterWeeklyDistribute() public {
        initializeVotingEscrow();

        minter.update_period();
        assertEq(minter.weekly(), 1_838_000 * 1e18); // 15M
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        assertEq(distributor.claimable(1), 0);
        assertLt(minter.weekly(), 1_838_000 * 1e18); // <15M for week shift
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);
        minter.update_period();
        // we disabled rebase
        uint256 claimable = distributor.claimable(1);
        assertEq(claimable, 0);
    }
}
