// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IRouter {
    function pairFor(address tokenA, address tokenB, bool stable) external view returns (address pair);

    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity);

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);
}
