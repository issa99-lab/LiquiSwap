// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity ^0.8.18;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiquiPool is ERC20 {
    error AmoutIsZero(uint256 _amount);
    error MinimumDepositRequired(uint256 _wethAmountToDeposit);
    error PoolTokenToDepositTooHigh(uint256 _poolTokenToDeposit);
    error LiquidityToMintTooHigh(uint256 liquidityTokensToMint);

    using SafeERC20 for IERC20;

    event LiquidityTokensMinted(address lp, uint256 _poolTokensToMint);
    //State variables
    IERC20 private immutable i_wethToken;
    IERC20 private immutable i_token;

    uint256 private constant MINIMUM_WETH_TO_DEPOSIT = 1000000;

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
    function swapExactInputAmount() external {}

    function swapExactOutputAmount() external {}

    function swap() external {}

    //done before swapping..eg. user has 50 usdc and wants to know how much he'll get in weth. will calculate the amount of weth they'll receive based on their input. (-= > usdc - transaction cost)
    function getOutputBasedOnInputAmount() external {}

    //done before swapping..eg. user has usdc and wants 1 weth. will calculate the amount of usdc they should send inorder to receive 1 weth. -= > usdc + transaction cost
    function getInputBasedOnOutputAmount() external {}

    function sellPoolToken() external {}

    function _isUnknown(address _token) internal view returns (bool) {}

    function totalLiquidityTokenSupply() public view returns (uint256) {
        return totalSupply();
    }
}
