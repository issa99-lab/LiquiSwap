// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity ^0.8.18;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LiquiPool is ERC20 {
    using SafeERC20 for IERC20;

    //State variables
    IERC20 private immutable i_wethToken;
    IERC20 private immutable i_token;

    constructor(
        address _weth,
        address _token,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) {
        i_wethToken = IERC20(_weth);
        i_token = IERC20(_token);
    }

    //invariant x * y = k

    //LP's deposit token & weth, given liquidity tokens to track their investment. Invariant should hold
    function deposit() external {}

    //user comes in and swaps either token for weth, or weth for token
    function swap() external {}

    //done before swapping..eg. user has 50 usdc and wants to know how much he'll get in weth. will calculate the amount of weth they'll receive based on their input. (-= > usdc - transaction cost)
    function getOutputBasedOnInput() external {}

    //done before swapping..eg. user has usdc and wants 1 weth. will calculate the amount of usdc they should send inorder to receive 1 weth. -= > usdc + transaction cost
    function getInputBasedOnOutput() external {}
}
