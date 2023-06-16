// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "contracts/libraries/Math.sol";
import "contracts/interfaces/IMinter.sol";
import "contracts/interfaces/IRewardsDistributor.sol";
import "contracts/interfaces/IOption.sol";
import "contracts/interfaces/IToken.sol";
import "contracts/interfaces/IVoter.sol";
import "contracts/interfaces/IVotingEscrow.sol";

// codifies the minting rules as per ve(3,3), abstracted from the token to support any token that allows minting

contract Minter is IMinter {
    uint internal constant WEEK = 86400 * 7; // allows minting once per week (reset every Thursday 00:00 UTC)
    uint internal constant EMISSION = 990;
    uint internal constant TAIL_EMISSION = 2;
    uint internal constant PRECISION = 1000;
    IOption public immutable _option;
    IToken public immutable _token;
    IVoter public immutable _voter;
    IVotingEscrow public immutable _ve;
    IRewardsDistributor public immutable _rewards_distributor;
    uint public weekly = 1_838_000 * 1e18; // represents a starting weekly emission of 1.838M OPTION (OPTION has 18 decimals)
    uint public active_period;
    uint internal constant LOCK = 86400 * 7 * 52 * 4;
    uint epochStart = 0;
    address internal initializer;
    address public team;
    bool public teamEmissionsActive = false;
    address public pendingTeam;
    uint public teamRate;
    uint public constant MAX_TEAM_RATE = 60; // 60 bps = 0.06%

    event Mint(address indexed sender, uint weekly, uint circulating_supply, uint circulating_emission);

    constructor(
        address __token, // the mintable token
        address __voter, // the voting & distribution system
        address __ve, // the ve(3,3) system that will be locked into
        address __rewards_distributor // the distribution system that ensures users aren't diluted
    ) {
        epochStart = block.timestamp;
        initializer = msg.sender;
        team = msg.sender;
        teamRate = 60; // 60 bps = 0.06%
        _token = IToken(__token);
        _option = IOption(IVotingEscrow(__ve).option());
        _voter = IVoter(__voter);
        _ve = IVotingEscrow(__ve);
        _rewards_distributor = IRewardsDistributor(__rewards_distributor);
        active_period = ((block.timestamp + (2 * WEEK)) / WEEK) * WEEK;
    }

    function initialize(
        address[] memory claimants,
        uint[] memory amounts
    ) external {
        require(initializer == msg.sender);
        for (uint i = 0; i < claimants.length; i++) {
            _option.mint(claimants[i], amounts[i]);
        }
        initializer = address(0);
        active_period = ((block.timestamp) / WEEK) * WEEK; // allow minter.update_period() to mint new emissions THIS Thursday
    }

    function setTeam(address _team) external {
        require(msg.sender == team, "not team");
        pendingTeam = _team;
    }

    function acceptTeam() external {
        require(msg.sender == pendingTeam, "not pending team");
        team = pendingTeam;
    }

    function setTeamRate(uint _teamRate) external {
        require(msg.sender == team, "not team");
        require(_teamRate <= MAX_TEAM_RATE, "rate too high");
        teamRate = _teamRate;
    }

    function setTeamEmissionsActive(bool _teamEmissionsActive) external {
        require(msg.sender == team, "not team");
        teamEmissionsActive = _teamEmissionsActive;
    }

    function getEpoch() public view returns (uint) {
        return (block.timestamp - epochStart) / WEEK;
    }

    // calculate circulating supply as total token supply - locked supply
    function circulating_supply() public view returns (uint) {
        return (_token.totalSupply() + _option.totalSupply() ) - _ve.totalSupply();
    }

    // emission calculation is 1% of available supply to mint adjusted by circulating / total supply
    function calculate_emission() public view returns (uint) {
        return (weekly * EMISSION) / PRECISION;
    }

    // weekly emission takes the max of calculated (aka target) emission versus circulating tail end emission
    function weekly_emission() public view returns (uint) {
        return Math.max(calculate_emission(), circulating_emission());
    }

    // calculates tail end (infinity) emissions as 0.2% of total supply
    function circulating_emission() public view returns (uint) {
        return (circulating_supply() * TAIL_EMISSION) / PRECISION;
    }

    // update period can only be called once per cycle (1 week)
    function update_period() external returns (uint) {
        uint _period = active_period;
        if (block.timestamp >= _period + WEEK && initializer == address(0)) { // only trigger if new week
            _period = (block.timestamp / WEEK) * WEEK;
            active_period = _period;
            weekly = weekly_emission();
            uint _teamEmissions = 0;
            if( teamEmissionsActive ){
                _teamEmissions = (teamRate * weekly) / (PRECISION - teamRate);
                _token.mint(team, _teamEmissions);
            }
            uint _balanceOf = _option.balanceOf(address(this));
            if (_balanceOf < weekly) {
                _option.mint(address(this), weekly - _balanceOf);
            }

            _rewards_distributor.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
            _rewards_distributor.checkpoint_total_supply(); // checkpoint supply

            _option.approve(address(_voter), weekly);
            _voter.notifyRewardAmount(weekly);

            emit Mint(msg.sender, weekly, circulating_supply(), circulating_emission());
        }
        return _period;
    }
}
