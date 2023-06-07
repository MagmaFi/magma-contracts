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
        oracle = new UniswapV2Oracle(pairAddress, address(token));

        // prevent timestamp calculation problem in the oracle:
        vm.warp(1686178415);

    }

    function testSwap() public{

        token.mint(address(this), 100_000e18);
        usdc.mint(100_000e6);

        token.approve(address(router2), 100_000e18);
        usdc.approve(address(router2), 100_000e6);

        router2.addLiquidity(address(token), address(usdc), false, 100_000e18, 100_000e6, 0, 0, address(this), block.timestamp);

        Router.route[] memory routes = new Router.route[](1);
        routes[0] = Router.route(address(usdc), address(token), false);

        uint tokenDecimals = usdc.decimals();

        uint swapTimes = 100;
        uint buyAmount = 10;
        for(uint i = 0; i < swapTimes; i++){
            uint buyAmountInWei = 10 ** tokenDecimals * buyAmount;
            usdc.mint(buyAmountInWei);
            usdc.approve(address(router2), buyAmountInWei);
            router2.swapExactTokensForTokens(buyAmountInWei, 0, routes, address(this), block.timestamp);
            uint ts = block.timestamp + 10 minutes;
            vm.warp(ts);
            uint price = oracle.getPrice();
            console.log("%s) price %s", i, price);
        }

    }
}
