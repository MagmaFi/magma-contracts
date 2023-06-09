// SPDX-License-Identifier: MIT

// Primary Author(s)
// Vahid: https://github.com/vahid-dev
// Sina: https://github.com/spsina

import "../interfaces/IBaseV1Pair.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IOracle.sol";
//import "forge-std/console2.sol";
pragma solidity 0.8.17;

/// @title Oracle
/// @notice calculate twap price of solidly pair token0/token1
contract UniswapV2Oracle is IOracle {
    address public baseV1Pair;
    address public token0;
    address public token1;
    address public tokenPrice;
    uint256 public tokenDecimals;
    uint256 public decimals0;
    uint256 public decimals1;
    bool public stable;
    uint public interval = 3 hours;
    uint public twapInterval = 30;
    constructor(address baseV1Pair_, address tokenPrice_) {
        baseV1Pair = baseV1Pair_;
        tokenPrice = tokenPrice_;
        tokenDecimals = IERC20(tokenPrice).decimals();
        token0 = IBaseV1Pair(baseV1Pair).token0();
        token1 = IBaseV1Pair(baseV1Pair).token1();
        decimals0 = IERC20(token0).decimals();
        decimals1 = IERC20(token1).decimals();
        stable = IBaseV1Pair(baseV1Pair).stable();
    }

    function getPrice() public view returns (uint256) {
        uint one = 10 ** tokenDecimals * 1;
        uint since = block.timestamp - 30 minutes;
        uint256[] memory prices = price(tokenPrice, one, since, 25 minutes);
        if( prices.length == 0 ) return 0;
        return prices[0];
    }

    /**
     * @notice calculates the maximum points needed to get back to the specified timestamp
     * @param timestamp specific timestamp
     * @return searchIndex the index of the observation that is closest to the specified timestamp
     */
    function getFirstSearchIndex(uint256 timestamp)
    public
    view
    returns (uint256 searchIndex)
    {
        uint256 length = IBaseV1Pair(baseV1Pair).observationLength();
        uint256 delta = block.timestamp - timestamp;
        uint256 maxPointsNeeded = delta / 30 minutes;
        if( length == 1 ){
            searchIndex = 0;
        }else{
            searchIndex = length - (maxPointsNeeded + 1);
        }
    }

    /**
     * @notice calculates the exact index of the observation that is closest to the specified timestamp
     * @param timestamp specific timestamp
     * @return fromIndex the index of the observation that is closest to the specified timestamp
     */
    function getIndexAt(uint256 timestamp) public view returns (uint256) {
        uint256 length = IBaseV1Pair(baseV1Pair).observationLength();
        uint256 index = getFirstSearchIndex(timestamp);
        //console2.log(" - index", index, timestamp);
        uint256 since = IBaseV1Pair(baseV1Pair).observations(index).timestamp;
        //console2.log(" - since", since);
        while (since < timestamp) {
            index++;
            if( index >= length ) break;
            since = IBaseV1Pair(baseV1Pair).observations(index).timestamp;
        }
        return index - 1;
    }

    /**
     * @notice calculates the twap range
     * @param timestamp specific timestamp
     * @param duration duration of twap
     * @return from the index of the observation that is closest to the specified timestamp
     * @return to the index of the observation that is closest to the specified timestamp + duration
     */
    function getRange(uint256 timestamp, uint256 duration)
    public
    view
    returns (uint256 from, uint256 to)
    {
        from = getIndexAt(timestamp);
        to = getIndexAt(timestamp + duration);
    }

    /**
     * @notice calculates the twap price of token0/token1
     * @param timestamp specific timestamp
     * @return _twap the twap price of token0/token1
     */
    function twap(
        address tokenIn,
        uint256 amountIn,
        uint256 timestamp,
        uint256 duration
    ) external view returns (uint256 _twap) {
        uint256[] memory prices = price(tokenIn, amountIn, timestamp, duration);
        uint256 sum = 0;
        for (uint256 index = 0; index < prices.length; index++) {
            sum += prices[index];
        }
        _twap = sum / prices.length;
    }

    /**
     * @notice returns the price sample from timestamp to timestamp + duration for tokenIn
     * @param tokenIn token to get price sample
     * @param amountIn amount of token to get price sample
     * @param timestamp specific timestamp
     * @param duration duration of twap
     * @return prices the price sample from timestamp to timestamp + duration for tokenIn
     */
    function price(
        address tokenIn,
        uint256 amountIn,
        uint256 timestamp,
        uint256 duration
    ) public view returns (uint256[] memory prices) {
        (uint256 fromIndex, uint256 toIndex) = getRange(timestamp, duration);
        //uint256 length = IBaseV1Pair(baseV1Pair).observationLength();
        //console2.log(" -- fromIndex=%s toIndex=%s length=%s", fromIndex, toIndex, length);
        prices = sample(tokenIn, amountIn, fromIndex, toIndex);
    }

    /**
     * @notice returns price samples from fromIndex to toIndex for tokenIn
     * @param tokenIn token to get price sample
     * @param amountIn amount of token to get price sample
     * @param fromIndex the index of the observation that is closest to the specified timestamp
     * @param toIndex the index of the observation that is closest to the specified timestamp + duration
     * @return _prices the price samples from fromIndex to toIndex for tokenIn
     */
    function sample(
        address tokenIn,
        uint256 amountIn,
        uint256 fromIndex,
        uint256 toIndex
    ) public view returns (uint256[] memory) {
        uint size = toIndex - fromIndex + 1;
        uint256[] memory _prices = new uint256[](size);
        uint256 nextIndex;
        uint256 index;
        uint256 length = IBaseV1Pair(baseV1Pair).observationLength();
        if( fromIndex == 0 ) return new uint256[](0);
        for (uint256 i = fromIndex-1; i < toIndex; i++) {
            nextIndex = i + 1;
            //console2.log(" -- i=%s nextIndex=%s length=%s", i, nextIndex, length);
            if( nextIndex >= length){
                //console2.log(" -- i=%s nextIndex=%s length=%s", i, nextIndex, length);
                break;
            }
            uint256 timeElapsed = IBaseV1Pair(baseV1Pair)
            .observations(nextIndex)
            .timestamp - IBaseV1Pair(baseV1Pair).observations(i).timestamp;
            uint256 _reserve0 = (IBaseV1Pair(baseV1Pair)
            .observations(nextIndex)
            .reserve0Cumulative -
                IBaseV1Pair(baseV1Pair).observations(i).reserve0Cumulative) /
            timeElapsed;
            uint256 _reserve1 = (IBaseV1Pair(baseV1Pair)
            .observations(nextIndex)
            .reserve1Cumulative -
                IBaseV1Pair(baseV1Pair).observations(i).reserve1Cumulative) /
            timeElapsed;
            _prices[index] = _getAmountOut(
                amountIn,
                tokenIn,
                _reserve0,
                _reserve1
            );
            index++;
        }
        return _prices;
    }

    /**
     * @dev This is an identical function to the one in the baseV1Pair contract.
     */
    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        uint256 _reserve0,
        uint256 _reserve1
    ) internal view returns (uint256) {
        if (stable) {
            uint256 xy = _k(_reserve0, _reserve1);
            _reserve0 = (_reserve0 * 1e18) / decimals0;
            _reserve1 = (_reserve1 * 1e18) / decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            amountIn = tokenIn == token0
                ? (amountIn * 1e18) / decimals0
                : (amountIn * 1e18) / decimals1;
            uint256 y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
            return (y * (tokenIn == token0 ? decimals1 : decimals0)) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0
                ? (_reserve0, _reserve1)
                : (_reserve1, _reserve0);
            return (amountIn * reserveB) / (reserveA + amountIn);
        }
    }

    /**
     * @dev This is an identical function to the one in the baseV1Pair contract.
     */
    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        if (stable) {
            uint256 _x = (x * 1e18) / decimals0;
            uint256 _y = (y * 1e18) / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return (_a * _b) / 1e18; // x3y+y3x >= k
        } else {
            return x * y; // xy >= k
        }
    }

    /**
     * @dev This is an identical function to the one in the baseV1Pair contract.
     */
    function _get_y(
        uint256 x0,
        uint256 xy,
        uint256 y
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    /**
     * @dev This is an identical function to the one in the baseV1Pair contract.
     */
    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        return
        (x0 * ((((y * y) / 1e18) * y) / 1e18)) /
        1e18 +
        (((((x0 * x0) / 1e18) * x0) / 1e18) * y) /
        1e18;
    }

    /**
     * @dev This is an identical function to the one in the baseV1Pair contract.
     */
    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return
        (3 * x0 * ((y * y) / 1e18)) /
        1e18 +
        ((((x0 * x0) / 1e18) * x0) / 1e18);
    }
}