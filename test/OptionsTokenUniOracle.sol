pragma solidity 0.8.13;

import './BaseTest.sol';
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {UniswapV2Oracle} from "../contracts/options-token/oracles/UniswapV2Oracle.sol";
import {Magma} from "../contracts/Magma.sol";
import {OptionsToken} from "../contracts/options-token/OptionsToken.sol";
import {TestERC20Mintable} from "./mocks/TestERC20Mintable.sol";
import {BalancerOracle} from "../contracts/options-token/oracles/BalancerOracle.sol";
import {IERC20Mintable} from "../contracts/options-token/interfaces/IERC20Mintable.sol";
import {MockBalancerTwapOracle} from "./mocks/MockBalancerTwapOracle.sol";
import {FaucetERC20d6} from "../contracts/mock/FaucetERC20d6.sol";
contract OptionsTokenUniOracle is BaseTest {

    FaucetERC20d6 usdc;
    Magma token;
    OptionsToken option;
    UniswapV2Oracle oracle;

    address pairAddress;

    function setUp() public {
        factory = new PairFactory();
        WETH = new TestWETH();
        usdc = new FaucetERC20d6("USDC", "USDC", 0);
        router2 = new Router2(address(factory), address(WETH));
        token = new Magma();
        pairAddress = factory.createPair(address(token), address(usdc), false);
        pair = Pair(pairAddress);
        oracle = new UniswapV2Oracle(pairAddress);

    }

    function testSwap() public{

        token.mint(address(this), 100_000e18);
        usdc.mint(100_000e6);

        token.approve(address(router2), 100_000e18);
        usdc.approve(address(router2), 100_000e6);

        router2.addLiquidity(address(token), address(usdc), false, 100_000e18, 100_000e6, 0, 0, address(this), block.timestamp);

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(usdc), address(token), false);

        uint buyAmount = 100e6;
        usdc.mint(buyAmount);
        usdc.approve(address(router2), buyAmount);
        uint swapAmount = 1e6;
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);
        router2.swapExactTokensForTokens(swapAmount, 0, routes, address(this), block.timestamp);
        vm.warp(block.timestamp+3600);

        uint256[] memory prices = oracle.price(address(usdc), 100e6, block.timestamp-12000, 30);
        uint priceInWei = prices[0];
        console.log("priceInWei", priceInWei);

    }
}
