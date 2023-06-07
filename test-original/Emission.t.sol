pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
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
import "contracts/MagmaGovernor.sol";
import "utils/TestOwner.sol";
import "utils/TestStakingRewards.sol";
import "utils/TestToken.sol";
import "utils/TestVoter.sol";
import "utils/TestVotingEscrow.sol";
import "utils/TestWETH.sol";
contract Emission is Test {
    TestWETH WETH;
    MockERC20 DAI;
    uint TOKEN_100 = 100 * 1e18;
    Magma magma;
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
    function setUp() public {
        magma = new Magma();
        gaugeFactory = new GaugeFactory();
        bribeFactory = new BribeFactory();
        pairFactory = new PairFactory();
        WETH = new TestWETH();
        DAI = new MockERC20("DAI", "DAI", 18);
        router = new Router2(address(pairFactory), address(WETH));
        artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(magma), address(artProxy));
        distributor = new RewardsDistributor(address(escrow));
        voter = new Voter(address(escrow), address(pairFactory), address(gaugeFactory), address(bribeFactory));
        minter = new Minter(address(voter), address(escrow), address(distributor));
        governor = new MagmaGovernor(escrow);
        // ---
        magma.initialMint(address(this));
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
    }
    function getEpoch() public returns(uint){
        InternalBribe bribe = InternalBribe(gauge_eth_magma.internal_bribe());
        return bribe.getEpochStart(block.timestamp);
    }
    function testExec() public {
        vm.warp(block.timestamp + 86400 * 7);
        vm.roll(block.number + 1);

        gauge_eth_magma = Gauge(voter.createGauge(address(pool_eth_magma)));
        vm.roll(block.number + 1);
        uint duration = 4 * 365 * 86400;
        magma.approve(address(escrow), magma.balanceOf(address(this)));
        uint id = escrow.create_lock(magma.balanceOf(address(this)), duration);

        address[] memory pools = new address[](1);
        pools[0] = address(pool_eth_magma);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        console.log('epoch 0', getEpoch());
        vm.warp(block.timestamp + 86400 * 3);
        vm.roll(block.number + 1);
        voter.vote(id, pools, weights);
        voter.distro();
        console.log('epoch 0', getEpoch());
        vm.warp(block.timestamp + (86400 * 4)+ 1 );
        vm.roll(block.number + 1);
        console.log('epoch 1', getEpoch());

        address[] memory emptyAddresses = new address[](1);
        emptyAddresses[0] = address(this);
        uint[] memory emptyAmounts = new uint[](1);
        emptyAmounts[0] = 1e18;
        minter.initialize(emptyAddresses, emptyAmounts, 1e18);
        console.log('a', magma.balanceOf(address(this))/1e18);
        voter.distro();
        console.log('b', magma.balanceOf(address(this))/1e18);
        vm.warp(block.timestamp + (86400 * 7)+ 1 );
        vm.roll(block.number + 1);
        console.log('epoch 2', getEpoch());
        voter.distro();
        console.log('c', magma.balanceOf(address(this))/1e18);
    }

}