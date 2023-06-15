// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IOption {
    function totalSupply() external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
    function mint(address, uint) external;
    function minter() external returns (address);
    function claim(address, uint) external returns (bool);
}
