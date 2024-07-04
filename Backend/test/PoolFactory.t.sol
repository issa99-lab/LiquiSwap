// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract PoolFactoryTest is Test {
    PoolFactory factory;
    ERC20Mock weth;
    ERC20Mock tokenA;

    address user1 = makeAddr("123");

    function setUp() public {
        weth = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        tokenA = new ERC20Mock();
    }

    function testFailAnyoneCanCreateFactory() public {
        vm.prank(user1);
        factory.createPool(address(tokenA));
    }

    function testOnlyAdminCanCreatePool() public {
        vm.prank(factory.poolOwner());
        factory.createPool(address(tokenA));
    }

    function testPoolCreate() public {
        address poolAddress = factory.createPool(address(tokenA));
        assertEq(poolAddress, factory.getPoolAddress(address(tokenA)));
        assertEq(address(tokenA), factory.getTokenAddress(poolAddress));
    }

    function testFailUserSetsOwner(address newOwner) public {
        vm.prank(user1);
        factory.setNewOwner(newOwner);
    }

    function testOnlyAdminCanSetOwner(address newOwner) public {
        vm.prank(factory.poolOwner());
        factory.setNewOwner(newOwner);
    }

    function testIwethToken() public view {
        assertEq(address(weth), factory.getWethToken());
    }
}
