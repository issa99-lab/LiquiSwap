// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity ^0.8.18;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiquiPool is ERC20 {
    ////ERRORS////
    error AmountIsZero(uint256 _amount);
    error DeadlinePassed(uint256 _deadline);
    error MinimumDepositRequired(uint256 _wethAmountToDeposit);
    error PoolTokenToDepositTooHigh(uint256 _poolTokenToDeposit);
    error LiquidityToMintTooHigh(uint256 _liquidityTokensToMint);
    error OutputAmountTooLow(uint256 _outputAmount);
    error MaxDepositReached(uint256 _inputAmount);
    error InvalidTokens();

    using SafeERC20 for IERC20;

    event LiquidityTokensMinted(address lp, uint256 _poolTokensToMint);
    event SwapComplete(
        address indexed swapper,
        uint256 indexed _tokenAmount,
        uint256 indexed _outputAmount
    );

    //State variables
    IERC20 private immutable i_wethToken;
    IERC20 private immutable i_token;

    uint256 private constant MINIMUM_WETH_TO_DEPOSIT = 1000000;

    uint256 private constant PRECISION = 1000;
    uint256 private constant MINUS_FEE = 997;

    constructor(
        address _weth,
        address _token,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) {
        i_wethToken = IERC20(_weth);
        i_token = IERC20(_token);
    }

    modifier revertIfZero(uint256 amount) {
        if (amount <= 0) {
            revert AmoutIsZero(amount);
        }
        _;
    }

    modifier revertIfDeadlineHasPassed(uint64 _deadline) {
        if (_deadline > uint64(block.timestamp)) {
            revert DeadlinePassed(_deadline);
        }
        _;
    }

    //@dev invariant x * y = k

    //LP's deposit token & weth, given liquidity tokens to track their investment. Invariant should hold
    function deposit(
        uint256 _wethAmountToDeposit,
        uint256 _maximumLiquidityTokenToMint,
        uint256 _maximumPoolTokenToDeposit
    ) external revertIfZero(_wethAmountToDeposit) {
        if (_wethAmountToDeposit < MINIMUM_WETH_TO_DEPOSIT) {
            revert MinimumDepositRequired(_wethAmountToDeposit);
        }

        //if there's liquidity
        if (totalLiquidityTokenSupply() > 0) {
            uint256 wethReserves = i_wethToken.balanceOf(address(this));

            uint256 _poolTokenToDeposit = getPoolTokensToDepositBasedOnWeth(
                _wethAmountToDeposit
            );
            if (_maximumPoolTokenToDeposit < _poolTokenToDeposit) {
                revert PoolTokenToDepositTooHigh(_poolTokenToDeposit);
            }

            uint256 liquidityTokensToMint = (_wethAmountToDeposit *
                totalLiquidityTokenSupply()) / wethReserves;
            if (_maximumLiquidityTokenToMint < liquidityTokensToMint) {
                revert LiquidityToMintTooHigh(liquidityTokensToMint);
            }

            addAndMintLiquidityTokens(
                _wethAmountToDeposit,
                _poolTokenToDeposit,
                liquidityTokensToMint
            );
        }
        //first time deposit, no liquidity
        else {
            addAndMintLiquidityTokens(
                _wethAmountToDeposit,
                _maximumPoolTokenToDeposit,
                _wethAmountToDeposit
            );
        }
    }

    function getPoolTokensToDepositBasedOnWeth(
        uint256 _wethAmountToDeposit
    ) public view returns (uint256) {
        uint256 wethReserves = i_wethToken.balanceOf(address(this)); //y
        uint256 tokenReserves = i_token.balanceOf(address(this)); //x

        return (_wethAmountToDeposit * tokenReserves) / wethReserves;
        // ^x = ^y * x/ y
    }

    function addAndMintLiquidityTokens(
        uint256 _wethToDeposit,
        uint256 _poolTokensToDeposit,
        uint256 _poolTokensToMint
    ) private {
        _mint(msg.sender, _poolTokensToMint);
        emit LiquidityTokensMinted(msg.sender, _poolTokensToMint);

        i_wethToken.safeTransferFrom(msg.sender, address(this), _wethToDeposit);
        i_token.safeTransferFrom(
            msg.sender,
            address(this),
            _poolTokensToDeposit
        );
    }

    // remove liquidity by LP
    function withdraw() external {}

    //user comes in and swaps either token for weth, or weth for token
    function swapExactInput(
        IERC20 _token,
        uint256 _maximumTokensToDeposit,
        IERC20 _weth,
        uint256 _minimumWethToReceive,
        uint64 _deadline
    )
        external
        revertIfZero(_maximumTokensToDeposit)
        revertIfDeadlineHasPassed(_deadline)
    {
        uint256 tokenReserves = _token.balanceOf(address(this));
        uint256 wethReserves = _weth.balanceOf(address(this));
        uint256 outputAmount = getOutputBasedOnInputAmount(
            _maximumTokensToDeposit,
            tokenReserves,
            wethReserves
        );

        if (outputAmount < _minimumWethToReceive) {
            revert OutputAmountTooLow(outputAmount);
        }
        swap(_token, _maximumTokensToDeposit, _weth, outputAmount);
    }

    /*@notice  I want to get 10 weth, how much tokens should I deposit?*/
    function swapExactOutput(
        IERC20 _weth,
        uint256 _minWethToReceive,
        IERC20 _token,
        uint256 _maxTokensToDeposit,
        uint64 _deadline
    )
        external
        revertIfZero(_maxTokensToDeposit)
        revertIfDeadlineHasPassed(_deadline)
    {
        uint256 wethReserves = _weth.balanceOf(address(this));
        uint256 tokenReserves = _token.balanceOf(address(this));
        uint256 inputAmount = getInputBasedOnOutput(
            _minWethToReceive,
            wethReserves,
            tokenReserves
        );

        if (_maxTokensToDeposit < inputAmount) {
            revert MaxDepositReached(inputAmount);
        }
        emit SwapComplete(msg.sender, inputAmount, _minWethToReceive);
        swap(_token, inputAmount, _weth, _minWethToReceive);
    }

    /*@notice Swap input token (usdc) for output token, weth*/
    function swap(
        IERC20 _inputToken,
        uint256 _tokenAmount,
        IERC20 _outputToken,
        uint256 _outputAmount
    ) public revertIfZero(_tokenAmount) {
        if (
            _isUnknown(_inputToken) ||
            _isUnknown(_outputToken) ||
            _inputToken == _outputToken
        ) {
            revert InvalidTokens();
        }
        emit SwapComplete(msg.sender, _tokenAmount, _outputAmount);
        _inputToken.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        _outputToken.safeTransfer(msg.sender, _outputAmount);
    }

    /*@notice done before swapping..eg. user has 50 usdc and wants to know how much he'll get in weth. will calculate the amount of weth they'll receive based on their input, minus fees 0.03%*/
    function getOutputBasedOnInputAmount(
        uint256 _inputAmount,
        uint256 _inputReserves,
        uint256 _outputReserves
    ) public pure returns (uint256 outputAmount) {
        uint256 inputAmountMinusFee = _inputAmount * MINUS_FEE;
        uint256 numerator = inputAmountMinusFee * _outputReserves;
        uint256 denominator = (_inputReserves * PRECISION) +
            inputAmountMinusFee;

        return numerator / denominator;
    }

    //done before swapping..eg. user has usdc and wants 1 weth. will calculate the amount of usdc they should send inorder to receive 1 weth. -= > usdc + transaction cost
    function getInputBasedOnOutput(
        uint256 _wethAmount,
        uint256 _wethReserves,
        uint256 _tokenReserves
    )
        public
        pure
        revertIfZero(_wethAmount)
        revertIfZero(_wethReserves)
        returns (
            uint256 //input
        )
    {
        return
            (((_wethAmount * _tokenReserves) * PRECISION) /
                (_wethReserves - _wethAmount)) * MINUS_FEE;
    }

    function sellPoolToken() external {}

    function _isUnknown(IERC20 _token) internal view returns (bool) {
        if (_token != i_token && _token != i_wethToken) {
            return true;
        } else {
            return false;
        }
    }

    function totalLiquidityTokenSupply() public view returns (uint256) {
        return totalSupply();
    }
}
