import "../interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "contracts/interfaces/IPairFactory.sol";
import "contracts/interfaces/IRouter2.sol";

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;
contract TaxToken2 is IERC20, Ownable {
    string private constant _name = "test contract";
    string private constant _symbol = "test contract";
    uint8 private constant _decimals = 9;

    uint256 private constant _totalSupply = 100000000000000 * 10 ** 9;
    uint256 private constant _maxFee = 4; // Fees can not be set highter than this
    uint256 private _taxFeeOnBuy = 4;
    uint256 private _taxFeeOnSell = 4;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    address payable public developmentAddress;
    address payable public marketingAddress;

    IRouter2 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private inSwap = false;

    uint256 public _maxTxAmount = 2000000000000 * 10 ** 9;
    uint256 public _maxWalletSize = 2000000000000 * 10 ** 9;
    uint256 public _swapTokensAtAmount = 1000000000000 * 10 ** 9; // 0.1%

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        developmentAddress = payable(msg.sender);
        marketingAddress = payable(msg.sender);
        _balances[_msgSender()] = _totalSupply;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[developmentAddress] = true;
        _isExcludedFromFee[marketingAddress] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function initializeRouter( address _router ) external onlyOwner {

        require( address(uniswapV2Router) == address(0), "already initialized");

        uniswapV2Router = IRouter2(_router);

        address factoryAddress = uniswapV2Router.factory();
        address wethAddress = uniswapV2Router.weth();
        IPairFactory factory = IPairFactory(factoryAddress);

        uniswapV2Pair = factory.getPair(address(this), wethAddress, false);

        if( uniswapV2Pair == address(0) ){
            uniswapV2Pair = factory.createPair(
                address(this), wethAddress, false
            );
        }

    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
    unchecked {
        _approve(sender, _msgSender(), currentAllowance - amount);
    }
        _transfer(sender, recipient, amount);
        return true;
    }

    // private

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner()) {
            if (
                to != marketingAddress &&
                from != marketingAddress &&
                to != developmentAddress &&
                from != developmentAddress
            ) {
                require(amount <= _maxTxAmount, "TOKEN: Max Transaction Limit");
            }

            if (
                to != uniswapV2Pair &&
                to != marketingAddress &&
                from != marketingAddress &&
                to != developmentAddress &&
                from != developmentAddress
            ) {
                require(
                    balanceOf(to) + amount < _maxWalletSize,
                    "TOKEN: Balance exceeds wallet size!"
                );
            }
            uint256 contractTokenBalance = balanceOf(address(this));

            if (contractTokenBalance >= _maxTxAmount) {
                contractTokenBalance = _maxTxAmount;
            }

            bool canSwap = contractTokenBalance >= _swapTokensAtAmount;

            if (
                canSwap &&
                !inSwap &&
                from != uniswapV2Pair &&
                !_isExcludedFromFee[from] &&
                !_isExcludedFromFee[to]
            ) {
                swapTokensForEth(contractTokenBalance);

                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    marketingAddress.transfer(address(this).balance);
                }
            }
        }

        //Transfer Tokens
        uint256 _taxFee = 0;
        if (
            (_isExcludedFromFee[from] || _isExcludedFromFee[to]) ||
            (from != uniswapV2Pair && to != uniswapV2Pair)
        ) {
            _taxFee = 0;
        } else {
            //Set Fee for Buys
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                _taxFee = _taxFeeOnBuy;
            }

            //Set Fee for Sells
            if (to == uniswapV2Pair && from != address(uniswapV2Router)) {
                _taxFee = _taxFeeOnSell;
            }
        }

        _tokenTransfer(from, to, amount, _taxFee);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {

        IRouter2.route[] memory path = new IRouter2.route[](1);
        path[0] = IRouter2.route(address(this), address(uniswapV2Router.weth()), false);

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        uint256 tax
    ) private {
        uint256 tTeam = (amount * tax) / 100;
        uint256 tTransferAmount = amount - tTeam;
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + tTransferAmount;
        if (tTeam > 0) {
            _balances[address(this)] = _balances[address(this)] + tTeam;
            emit Transfer(sender, address(this), tTeam);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    // onlyOwner external

    function setFee(
        uint256 taxFeeOnBuy,
        uint256 taxFeeOnSell
    ) external onlyOwner {
        require(taxFeeOnBuy <= _maxFee, "Fee is too high");
        require(taxFeeOnSell <= _maxFee, "Fee is too high");

        _taxFeeOnBuy = taxFeeOnBuy;
        _taxFeeOnSell = taxFeeOnSell;
    }

    //Set minimum tokens required to swap.
    function setMinSwapTokensThreshold(
        uint256 swapTokensAtAmount
    ) external onlyOwner {
        _swapTokensAtAmount = swapTokensAtAmount;
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = excluded;
        }
    }

    receive() external payable {}
}