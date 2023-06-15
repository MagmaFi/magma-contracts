// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

/// ============ Imports ============

import {IOption} from "contracts/interfaces/IOption.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol"; // OZ: MerkleProof

/// @title MerkleClaim
/// @notice Claims OPTION for members of a merkle tree
/// @author Modified from Merkle Airdrop Starter (https://github.com/Anish-Agnihotri/merkle-airdrop-starter/blob/master/contracts/src/MerkleClaimERC20.sol)
contract MerkleClaim {
    /// ============ Immutable storage ============

    /// @notice OPTION token to claim
    IOption public immutable OPTION;
    /// @notice ERC20-claimee inclusion root
    bytes32 public immutable merkleRoot;

    /// ============ Mutable storage ============

    /// @notice Mapping of addresses who have claimed tokens
    mapping(address => bool) public hasClaimed;

    /// ============ Constructor ============

    /// @notice Creates a new MerkleClaim contract
    /// @param _token address
    /// @param _merkleRoot of claimees
    constructor(address _token, bytes32 _merkleRoot) {
        OPTION = IOption(_token);
        merkleRoot = _merkleRoot;
    }

    /// ============ Events ============

    /// @notice Emitted after a successful token claim
    /// @param to recipient of claim
    /// @param amount of tokens claimed
    event Claim(address indexed to, uint256 amount);

    /// ============ Functions ============

    /// @notice Allows claiming tokens if address is part of merkle tree
    /// @param amount of tokens owed to claimee
    /// @param proof merkle proof to prove address and amount are in tree
    function claim(
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        // Throw if address has already claimed tokens
        require(!hasClaimed[msg.sender], "ALREADY_CLAIMED");

        // Verify merkle proof, or revert if not in tree
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        bool isValidLeaf = MerkleProof.verify(proof, merkleRoot, leaf);
        require(isValidLeaf, "NOT_IN_MERKLE");

        // Set address to claimed
        hasClaimed[msg.sender] = true;

        // Claim tokens for address
        require(OPTION.claim(msg.sender, amount), "CLAIM_FAILED");

        // Emit claim event
        emit Claim(msg.sender, amount);
    }
}
