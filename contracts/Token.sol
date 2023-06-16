// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "contracts/interfaces/IToken.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract Token is IToken, AccessControl {

    string public constant name = "Magma";
    string public constant symbol = "MGM";
    uint8 public constant decimals = 18;
    uint public totalSupply = 0;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    // access control:
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    bool public initialMinted;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function removeMinter(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    // No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function addMinter(address _minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _minter);
    }

    function setRedemptionReceiver(address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _receiver);
    }

    function setMerkleClaim(address _merkleClaim) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _merkleClaim);
    }

    // Initial mint: total 40M
    function initialMint(address _recipient, uint amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!initialMinted,"ALREADY-MINTED");
        initialMinted = true;
        _mint(_recipient, amount);
    }

    function approve(address _spender, uint _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _mint(address _to, uint _amount) internal returns (bool) {
        totalSupply += _amount;
        unchecked {
            balanceOf[_to] += _amount;
        }
        emit Transfer(address(0x0), _to, _amount);
        return true;
    }

    function _transfer(address _from, address _to, uint _value) internal returns (bool) {

        require(balanceOf[_from] >= _value, "INSUFFICIENT-BALANCE");

        balanceOf[_from] -= _value;
        unchecked {
            balanceOf[_to] += _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint _value) external returns (bool) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) external returns (bool) {
        uint allowed_from = allowance[_from][msg.sender];
        if (allowed_from != type(uint).max) {
            allowance[_from][msg.sender] -= _value;
        }
        return _transfer(_from, _to, _value);
    }

    function mint(address account, uint amount) external onlyRole(MINTER_ROLE) returns (bool) {
        _mint(account, amount);
        return true;
    }

    function claim(address account, uint amount) external onlyRole(MINTER_ROLE) returns (bool) {
        _mint(account, amount);
        return true;
    }
}
