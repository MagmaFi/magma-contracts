pragma solidity 0.8.13;

import './BaseTest.sol';
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {Magma} from "../contracts/Magma.sol";
import {OptionsToken} from "../contracts/options-token/OptionsToken.sol";
import {TestERC20Mintable} from "./mocks/TestERC20Mintable.sol";
import {BalancerOracle} from "../contracts/options-token/oracles/BalancerOracle.sol";
import {IERC20Mintable} from "../contracts/options-token/interfaces/IERC20Mintable.sol";
import {MockBalancerTwapOracle} from "./mocks/MockBalancerTwapOracle.sol";

contract OptionsTokenUniOracle is BaseTest {

    Pair _pair;
    Magma token;
    OptionsToken option;

    uint TAX_TOKEN_100K = 100_000 * 1e9;
    uint TAX_TOKEN_1 = 1e9;
    uint TAX_TOKEN_100 = 100e9;
    uint TOKEN_100 = 100 * 1e18;
    uint liquidityAdded;
    function setUp() public {
        factory = new PairFactory();
        WETH = new TestWETH();
        router2 = new Router2(address(factory), address(WETH));
        token = new Magma();
        _pair = Pair(factory.getPair(address(token), address(WETH), false));
    }

    function testAddRemoveLiquidity() public {
        token.approve(address(router2), TAX_TOKEN_100K);
        WETH.approve(address(router2), TOKEN_100);

        uint amountEthBefore = address(this).balance;
        (,, liquidityAdded) =
        router2.addLiquidityETH{value : TOKEN_100}(address(token), false, TAX_TOKEN_100K, 0, 0, address(this), block.timestamp);
        uint amountEthAfter = address(this).balance;
        uint amountEthAdded = amountEthBefore - amountEthAfter;
        console2.log('amountEthBefore', amountEthBefore);
        console2.log('amountEthAfter', amountEthAfter);
        console2.log('amountEthAdded', amountEthAdded);
        assertEq(amountEthAfter, amountEthBefore - TOKEN_100);
        assertEq(amountEthAdded, TOKEN_100);

        _pair.approve(address(router2), liquidityAdded);
        router2.removeLiquidityETHSupportingFeeOnTransferTokens(address(token), false, liquidityAdded, 0, 0, address(this), block.timestamp);
        uint amountEthAfterRemove = address(this).balance;
        console2.log('amountEthAfterRemove', amountEthAfterRemove);
        assertEq(amountEthAfterRemove, amountEthBefore-1000000);

    }

    function testSwap() public{

        token.approve(address(router2), TAX_TOKEN_100K);
        WETH.approve(address(router2), TOKEN_100);

        uint amountEthBefore = address(this).balance;
        (,, liquidityAdded) =
        router2.addLiquidityETH{value : TOKEN_100}(address(token), false, TAX_TOKEN_100K, 0, 0, address(this), block.timestamp);
        uint amountEthAfter = address(this).balance;
        uint amountEthAdded = amountEthBefore - amountEthAfter;
        console2.log('amountEthBefore', amountEthBefore);
        console2.log('amountEthAfter', amountEthAfter);
        console2.log('amountEthAdded', amountEthAdded);
        assertEq(amountEthAfter, amountEthBefore - TOKEN_100);
        assertEq(amountEthAdded, TOKEN_100);

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(token), address(WETH), false);
        uint256[] memory expectedOutput = router2.getAmountsOut(TAX_TOKEN_100, routes);
        token.approve(address(router2), TAX_TOKEN_100);

        console2.log('tokenBalanceBeforeSwap', token.balanceOf(address(this))/1e9);
        router2.swapExactTokensForETHSupportingFeeOnTransferTokens(TAX_TOKEN_100, expectedOutput[1], routes, address(this), block.timestamp);
        console2.log('expectedOutput token', expectedOutput[0]/1e9);
        console2.log('expectedOutput eth', expectedOutput[1]);
        console2.log('tokenBalanceAfterSwap', token.balanceOf(address(this))/1e9);
        console2.log('amountEthAfterSwap', (address(this).balance - amountEthAfter));

        _pair.approve(address(router2), liquidityAdded);
        router2.removeLiquidityETHSupportingFeeOnTransferTokens(address(token), false, liquidityAdded, 0, 0, address(this), block.timestamp);
        uint amountEthAfterRemove = address(this).balance;
        console2.log('amountTokenAfterRemove', token.balanceOf(address(this)));
        console2.log('amountEthAfterRemove', amountEthAfterRemove/1e18);
        assertEq(amountEthAfterRemove, amountEthBefore - 999_004);

    }
}
