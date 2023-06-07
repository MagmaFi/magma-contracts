// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

struct Observation {
    uint256 timestamp;
    uint256 reserve0Cumulative;
    uint256 reserve1Cumulative;
}

interface IBaseV1Pair {
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function burn(address to) external returns (uint amount0, uint amount1);
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
    // additional views for oracle:
    function observations(uint256 index) external view returns (Observation calldata);
    function lastObservation() external view returns (Observation memory);
    function observationLength() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function stable() external view returns (bool);
}
