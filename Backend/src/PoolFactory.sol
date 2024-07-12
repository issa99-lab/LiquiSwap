//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {LiquiPool} from "./Pool.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";

contract PoolFactory {
    //-----ERRORS-----//
    error ERR_PoolExists(address);
    error ERR_AdminOnlyCall(address);

    //-----STATE VARIABLES----//
    mapping(address token => address pool) private s_pools;
    mapping(address pool => address token) private s_tokens;

    address private immutable i_wethToken;
    address public poolOwner;

    //-----EVENTS-----//
    event PoolCreated(address indexed tokenAddress, address indexed pool);
    event OwnerSet(address indexed newOwner);

    constructor(address _weth) {
        i_wethToken = _weth;
        poolOwner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != poolOwner) {
            revert ERR_AdminOnlyCall(msg.sender);
        }
        _;
    }

    //-----FUNCTIONS-----//
    //@dev creates a new pool of token address that is passed
    function createPool(address token) external onlyOwner returns (address) {
        if (s_pools[token] != address(0)) {
            revert ERR_PoolExists(token);
        }

        //LP tokens for investor eg.liquiUSDT
        string memory LiquiTokenName = string.concat(
            "Liqui",
            IERC20(token).name()
        );
        string memory LiquiTokenSymbol = string.concat(
            "Liqui",
            IERC20(token).symbol()
        );

        LiquiPool pool = new LiquiPool(
            i_wethToken,
            token,
            LiquiTokenName,
            LiquiTokenSymbol
        );
        s_pools[token] = address(pool);
        s_tokens[address(pool)] = token;
        emit PoolCreated(token, address(pool));
        return address(pool);
    }

    //
    function setNewOwner(
        address newOwner
    ) external onlyOwner returns (address) {
        poolOwner = newOwner;
        emit OwnerSet(newOwner);
        return newOwner;
    }

    //-----GETTERS-----//
    function getPoolAddress(address token) external view returns (address) {
        return s_pools[token];
    }

    function getTokenAddress(address pool) external view returns (address) {
        return s_tokens[pool];
    }

    function getWethToken() external view returns (address) {
        return i_wethToken;
    }
}
