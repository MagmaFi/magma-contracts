// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;
interface IERC20Claimable {
    function claim(address to, uint256 amount) external;
}