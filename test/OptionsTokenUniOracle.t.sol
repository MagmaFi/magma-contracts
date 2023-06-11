pragma solidity 0.8.13;
import './BaseTest.sol';
contract OptionsTokenUniOracle is BaseTest {
    function setUp() public {
        deployOptionsToken();
    }
    function testSwap() public{

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(WETH), address(MAGMA), false);

        uint MAGMADecimals = MAGMA.decimals();

        uint swapTimes = 100;
        uint buyAmount = 100e18;
        for(uint i = 0; i < swapTimes; i++){
            router2.swapExactETHForTokens{value: buyAmount}(0, routes, address(this), block.timestamp);
            uint ts = block.timestamp + 10 minutes;
            vm.warp(ts);
            uint price = oracle.getPrice();
            console.log("%s) price %s", i, price);
        }

    }
}
