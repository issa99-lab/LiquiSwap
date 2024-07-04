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
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        i_wethToken = IERC20(_weth);
        i_token = IERC20(_token);
    }
}
