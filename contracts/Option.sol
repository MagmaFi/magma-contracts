// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;


import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

import {IOracle} from "./interfaces/IOracle.sol";
import {IToken} from "contracts/interfaces/IToken.sol";
import {IRoute} from "contracts/interfaces/IRoute.sol";
import {IPairFactory} from "contracts/interfaces/IPairFactory.sol";
import {IPair} from "contracts/interfaces/IPair.sol";

/// @title Options Token
/// @author zefram.eth
/// @notice Options token representing the right to purchase the underlying token
/// at an oracle-specified rate. Similar to call options but with a variable strike
/// price that's always at a certain discount to the market price.
/// @dev Assumes the underlying token and the payment token both use 18 decimals.
contract Option is ERC20, AccessControl {

    // access control:
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------

    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error OptionsToken__PastDeadline();
    error OptionsToken__NotTokenMinter();
    error OptionsToken__SlippageTooHigh();

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Exercise(address indexed sender, address indexed recipient, uint256 amount, uint256 paymentAmount);
    event SetOracle(IOracle indexed newOracle);
    event SetTreasury(address indexed newTreasury);
    event SetMinter(address indexed newMinter);
    event SetDiscountRate(uint256 indexed newDiscountRate);
    event SetConversionRate(uint256 indexed newConversionRate);
    event ConvertToVe(address indexed sender, uint256 amount, uint256 amountToken, uint256 amountETH, uint256 liquidity, uint256 paymentAmount);

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    /// @notice The token paid by the options token holder during redemption
    ERC20 public paymentToken;

    /// @notice The underlying token purchased during redemption
    IToken public underlyingToken;

    /// @notice The route used to swap payment tokens for underlying tokens
    IRoute public route;

    /// @notice The pair used to transfer balance to user:
    IPair public pair;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// @notice The oracle contract that provides the current price to purchase
    /// the underlying token while exercising options (the strike price)
    IOracle public oracle;

    /// @notice The treasury address which receives tokens paid during redemption
    address public treasury;
    bool public initialMinted = false;

    // exerciseDiscountRate is the percentage of the oracle price that is
    // applied to the strike price. For example, if the oracle price
    // is $100 and the discount rate is 50%, then the strike price
    // is $50.
    uint public exerciseDiscountRate = 5000; // 50%

    // conversionDiscountRate is the percentage of the oracle price that is
    // applied to the conversion to veNFT price. For example, if the oracle price
    // is $100 and the discount rate is 10%, then the conversion price
    // is $90.
    uint public conversionDiscountRate = 9000; // 90%

    uint public DENOMINATOR = 10_000;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------
    constructor() ERC20("Option Magma", "oToken", 18) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    function initialize(
        IRoute route_,
        address minter_,
        ERC20 paymentToken_,
        IToken underlyingToken_,
        IOracle oracle_,
        address treasury_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(treasury == address(0), "already initialized");
        paymentToken = paymentToken_;
        underlyingToken = underlyingToken_;
        oracle = oracle_;
        treasury = treasury_;
        route = route_;

        IPairFactory pairFactory = IPairFactory(route.factory());
        // as we already setup oracle, we already have the pair:
        pair = IPair(pairFactory.getPair(address(underlyingToken), address(paymentToken)), false);

        _setupRole(MINTER_ROLE, minter_);

        emit SetOracle(oracle_);
        emit SetTreasury(treasury_);
    }

    function initialMint(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!initialMinted, "ALREADY-MINTED");
        initialMinted = true;
        _mint(to, amount);
    }

    function addMinter(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }

    function removeMinter(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
    }

    function setDiscountRate(uint256 newDiscountRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        exerciseDiscountRate = newDiscountRate;
        emit SetDiscountRate(newDiscountRate);
    }

    function setConversionDiscountRate(uint256 newDiscountRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        conversionDiscountRate = newDiscountRate;
        emit SetConversionRate(newDiscountRate);
    }

    /// -----------------------------------------------------------------------
    /// External functions
    /// -----------------------------------------------------------------------

    /// @notice Alias for compatibility with other contracts
    function claim(address to, uint256 amount) external {
        mint(to, amount);
    }

    /// @notice Called by the token admin to mint options tokens
    /// @param to The address that will receive the minted options tokens
    /// @param amount The amount of options tokens that will be minted
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {

        /// -----------------------------------------------------------------------
        /// State updates
        /// -----------------------------------------------------------------------

        // skip if amount is zero
        if (amount == 0) return;

        // mint options tokens
        _mint(to, amount);
    }

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The options tokens are not burnt but sent to address(0) to avoid messing up the
    /// inflation schedule.
    /// The oracle may revert if it cannot give a secure result.
    /// @param amount The amount of options tokens to exercise
    /// @param maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param recipient The recipient of the purchased underlying tokens
    /// @return paymentAmount The amount paid to the treasury to purchase the underlying tokens
    function exercise(uint256 amount, uint256 maxPaymentAmount, address recipient)
    external
    virtual
    returns (uint256 paymentAmount)
    {
        return _exercise(amount, maxPaymentAmount, recipient, exerciseDiscountRate);
    }

    /// @notice Exercises options tokens to purchase the underlying tokens.
    /// @dev The options tokens are not burnt but sent to address(0) to avoid messing up the
    /// inflation schedule.
    /// The oracle may revert if it cannot give a secure result.
    /// @param amount The amount of options tokens to exercise
    /// @param maxPaymentAmount The maximum acceptable amount to pay. Used for slippage protection.
    /// @param recipient The recipient of the purchased underlying tokens
    /// @param deadline The Unix timestamp (in seconds) after which the call will revert
    /// @return paymentAmount The amount paid to the treasury to purchase the underlying tokens
    function exercise(uint256 amount, uint256 maxPaymentAmount, address recipient, uint256 deadline)
    external
    virtual
    returns (uint256 paymentAmount)
    {
        if (block.timestamp > deadline) revert OptionsToken__PastDeadline();
        return _exercise(amount, maxPaymentAmount, recipient);
    }

    /// -----------------------------------------------------------------------
    /// Owner functions
    /// -----------------------------------------------------------------------

    /// @notice Sets the oracle contract. Only callable by the owner.
    /// @param oracle_ The new oracle contract
    function setOracle(IOracle oracle_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        oracle = oracle_;
        emit SetOracle(oracle_);
    }

    /// @notice Sets the treasury address. Only callable by the owner.
    /// @param treasury_ The new treasury address
    function setTreasury(address treasury_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = treasury_;
        emit SetTreasury(treasury_);
    }

    /// -----------------------------------------------------------------------
    /// Internal functions
    /// -----------------------------------------------------------------------

    function _exercise(uint256 amount, uint256 maxPaymentAmount,
        address recipient, uint _exerciseDiscountRate)
    internal
    virtual
    returns (uint256 paymentAmount)
    {
        // skip if amount is zero
        if (amount == 0) return 0;

        // transfer options tokens from msg.sender to address(0)
        // we transfer instead of burn because TokenAdmin cares about totalSupply
        // which we don't want to change in order to follow the emission schedule
        transfer(address(0), amount);

        // transfer payment tokens from msg.sender to the treasury
        paymentAmount = amount.mulWadUp(oracle.getPrice());
        if (_exerciseDiscountRate > 0) {
            // apply discount on exercise: 50% discount
            paymentAmount = paymentAmount.mulWadUp(DENOMINATOR - _exerciseDiscountRate).divWadUp(DENOMINATOR);
        }
        if (paymentAmount > maxPaymentAmount) {
            revert OptionsToken__SlippageTooHigh();
        }

        if (paymentAmount > 0) {
            // because of the exercise discount, paymentAmount can be zero
            paymentToken.safeTransferFrom(msg.sender, treasury, paymentAmount);
        }

        // mint underlying tokens to recipient
        underlyingToken.claim(recipient, amount);

        emit Exercise(msg.sender, recipient, amount, paymentAmount);
    }

    /// @notice Converts the options tokens to veNFT position.
    /// @param amount The amount of options tokens to convert
    /// @param maxPayment The maximum acceptable amount to pay for the options tokens.
    /// Used for slippage protection:
    /// @param amountTokenMin The minimum acceptable amount of options tokens to receive.
    /// @param amountETHMin The minimum acceptable amount of ETH to receive.
    function convertToVe(uint256 amount, uint maxPayment, uint amountTokenMin, uint amountETHMin) external payable {
        if (amount == 0 || msg.value == 0) return;
        uint balanceOfLpBefore = pair.balanceOf(address(this));
        uint paymentAmount = _exercise(amount, maxPayment, address(this), conversionDiscountRate);
        uint balanceOfLpAfter = pair.balanceOf(address(this));
        uint amountOfLp = balanceOfLpAfter.sub(balanceOfLpBefore);
        pair.approve(address(route), amountOfLp);
        (uint amountToken, uint amountETH, uint liquidity) = route.addLiquidityEth{value: msg.value}(
            address(underlyingToken),
            false,
            amountOfLp,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            block.timestamp);
        emit ConvertToVe(account, amount, amountToken, amountETH, liquidity, paymentAmount);
    }

    /// @notice Quote conversion of option to veNFT position, IE: how much payment tokens (MNT) will be paid
    /// @param amount The amount of options tokens to convert
    /// @return paymentAmount The amount of payment tokens (MNT) to pay for the conversion
    function quoteConversionToVe(uint256 amount) public view returns (uint256 paymentAmount) {
        uint paymentAmount = amount.mulWadUp(oracle.getPrice());
        if (conversionDiscountRate > 0) {
            paymentAmount = paymentAmount.mulWadUp(DENOMINATOR - conversionDiscountRate).divWadUp(DENOMINATOR);
        }
        return paymentAmount;
    }

    /// @notice Quote amount of LP received for conversion of option to veNFT position:
    /// @param amount The amount of options tokens to convert
    /// @return amountOfLp The amount of LP tokens to receive
    function quoteConversionToVeLp(uint256 amount) external view returns
    (uint mntPaymentExercisePayment, uint amountInMntForLp, uint totalMntNeeded)
    {
        uint mntPaymentExercisePayment = quoteConversionToVe(amount);
        // get amount out of mnt needed based in the amount of options tokens:
        (uint amountInMntForLp,) = route.getAmountsOut(amount, underlyingToken, paymentToken);
        uint totalMntNeeded = mntPaymentExercisePayment.add(amountInMntForLp);
        return (mntPaymentExercisePayment, amountInMntForLp, totalMntNeeded);
    }

}
