pragma solidity 0.8.17;

import "./BaseTest.sol";

contract LPRewardsTest is BaseTest {
    VotingEscrow escrow;
    GaugeFactory gaugeFactory;
    BribeFactory bribeFactory;
    Voter voter;
    Gauge gauge;

    function setUp() public {
        deployOwners();
        deployCoins();
        mintStables();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2 * TOKEN_1M; // use 1/2 for veNFT position
        amounts[1] = TOKEN_1M;
        mintOption(owners, amounts);

        // give owner1 veoToken
        VeArtProxy artProxy = new VeArtProxy();
        deployTokenEthPair(0, 0);
        escrow = new VotingEscrow(address(lp),address(oToken), address(artProxy));

        uint amount = lpAdd(address(this), 100 * TOKEN_1, 100 * TOKEN_1);
        lp.approve(address(escrow), amount);
        escrow.create_lock(amount, 4 * 365 * 86400);

        deployPairFactoryAndRouter();
        deployPairWithOwner(address(owner));
        deployPairWithOwner(address(owner2));
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        voter = new Voter(address(escrow), address(factory), address(gaugeFactory), address(bribeFactory));
        address[] memory tokens = new address[](4);
        tokens[0] = address(USDC);
        tokens[1] = address(FRAX);
        tokens[2] = address(DAI);
        tokens[3] = address(oToken);
        voter.initialize(tokens, address(owner));
        escrow.setVoter(address(voter));
    }

    function testLPsEarnEqualOptionBasedOnVeOption() public {
        // owner1 deposits LP
        USDC.approve(address(router), 1e12);
        FRAX.approve(address(router), TOKEN_1M);
        router.addLiquidity(address(FRAX), address(USDC), true, TOKEN_1M, 1e12, 0, 0, address(owner2), block.timestamp);
        address address1 = factory.getPair(address(FRAX), address(USDC), true);
        pair = Pair(address1);
        voter.createGauge(address(pair));
        address gaugeAddress = voter.gauges(address(pair));
        gauge = Gauge(gaugeAddress);
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1, 0);

        // owner2 deposits LP
        vm.startPrank(address(owner2));
        USDC.approve(address(router), 1e12);
        FRAX.approve(address(router), TOKEN_1M);
        router.addLiquidity(address(FRAX), address(USDC), true, TOKEN_1M, 1e12, 0, 0, address(owner2), block.timestamp);
        pair.approve(address(gauge), PAIR_1);
        gauge.deposit(PAIR_1, 0);
        vm.stopPrank();

        // fast forward time
        vm.warp(block.timestamp + 691200);
        vm.roll(block.number + 1);

        address[] memory rewards = new address[](1);
        rewards[0] = address(oToken);

        // check derived balance is the same
        assertEq(gauge.derivedBalance(address(owner)), gauge.derivedBalance(address(owner2)));
        // check that derived balance is 100% of balance
        assertEq(gauge.derivedBalance(address(owner)), PAIR_1);
    }
}