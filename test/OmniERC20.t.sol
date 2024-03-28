// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MockPortal} from "omni/contracts/test/utils/MockPortal.sol";
import {Test, console} from "forge-std/Test.sol";
import {OmniERC20} from "../src/token/OmniERC20.sol";

contract OmniERC20Test is Test {
    OmniERC20 token;
    MockPortal portal;

    function setUp() public {
        portal = new MockPortal();
        token = new OmniERC20("Test Token", "TT", address(portal));
    }

    function testConstructor() public view {
        assertEq(token.name(), "Test Token", "Name should match");
        assertEq(token.symbol(), "TT", "Symbol should match");
        assertEq(token.decimals(), 18, "Decimals should match");
    }

    function testSetChainAddressDirect() public {
        uint64 chainId = 100;
        address contractAddress = address(0xdead);

        vm.startPrank(token.owner());
        token.setChainAddress{value: 1 ether}(chainId, contractAddress);
        vm.stopPrank();

        assertEq(token.chainToContract(chainId), contractAddress, "Contract address should match");
    }
}