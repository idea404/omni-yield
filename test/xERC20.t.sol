// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {MockPortal} from "omni/contracts/test/utils/MockPortal.sol";
import {Test, console} from "forge-std/Test.sol";
import {xERC20} from "../src/token/xERC20.sol";

contract xERC20Test is Test {
    xERC20 token;
    MockPortal portal;
    address recipient = address(0x1);

    function setUp() public {
        portal = new MockPortal();
        token = new xERC20("Test Token", "TT", address(portal));
    }

    function testConstructor() public view {
        assertEq(token.name(), "Test Token", "Name should match");
        assertEq(token.symbol(), "TT", "Symbol should match");
        assertEq(token.decimals(), 18, "Decimals should match");
    }

    function testXReceive() public {
        uint256 mintAmount = 1000 * 1e18;
        uint64 sourceChainId = 100;

        // Use portal.mockXCall to simulate an xcall to token.xreceive(...)
        vm.prank(address(token));
        portal.mockXCall(sourceChainId, address(token), abi.encodeWithSignature("xreceive(address,uint256)", recipient, mintAmount));

        assertEq(token.balanceOf(recipient), mintAmount, "Minted amount should match");
    }

    function testXReceiveNonXCallReverts() public {
        // Attempt to call xreceive(...) without an xcall
        vm.expectRevert("xERC20: only xcall");
        token.xreceive(recipient, 1000);
    }

    function testXReceiveNonTokenAccountReverts() public {
        uint256 mintAmount = 1000 * 1e18;
        uint64 sourceChainId = 100;
        address sender = address(0xdead); // sender has no token balance

        // Use portal.mockXCall to simulate an xcall to token.xreceive(...) with a different recipient
        vm.prank(sender);
        vm.expectRevert("xERC20: only self xcall");
        portal.mockXCall(sourceChainId, address(token), abi.encodeWithSignature("xreceive(address,uint256)", sender, mintAmount));
        assertEq(token.balanceOf(sender), 0, "Sender should have no balance");
    }

    function testXSend() public payable {
        // First, simulate receiving tokens
        uint256 mintAmount = 1000 * 1e18;
        uint64 sourceChainId = 100;
        vm.prank(address(token));
        portal.mockXCall(sourceChainId, address(token), abi.encodeWithSignature("xreceive(address,uint256)", recipient, mintAmount));
        assertEq(token.balanceOf(recipient), mintAmount, "Minted amount should match");

        // fund the recipient with some ether
        vm.deal(recipient, 1 ether);

        // Prepare xsend parameters
        uint64 destChainId = 200;
        address destContract = address(0x2);

        // Calculate xcall fee
        bytes memory expectedXCallData = abi.encodeWithSignature("xreceive(address,uint256)", recipient, mintAmount);
        uint256 fee = portal.feeFor(destChainId, expectedXCallData);

        // Assert that xsend(...) calls portal.xcall(...) appropriately
        vm.expectCall(
            address(portal),
            fee,
            abi.encodeWithSignature("xcall(uint64,address,bytes)", destChainId, destContract, expectedXCallData)
        );

        // Simulate the call from the recipient with the correct balance
        vm.prank(recipient);
        token.xsend{value: fee}(destChainId, destContract, recipient, mintAmount);

        assertEq(token.balanceOf(recipient), 0, "Balance after burn should be 0");
    }

    function testXSendInsufficientFeeReverts() public {
        // First, simulate receiving tokens
        uint256 mintAmount = 1000 * 1e18;
        uint64 sourceChainId = 100;
        vm.prank(address(token));
        portal.mockXCall(sourceChainId, address(token), abi.encodeWithSignature("xreceive(address,uint256)", recipient, mintAmount));
        assertEq(token.balanceOf(recipient), mintAmount, "Minted amount should match");

        // fund the recipient with some ether
        vm.deal(recipient, 1 ether);

        // Prepare xsend parameters
        uint64 destChainId = 2;
        address destContract = address(0xdeadbeef);
        uint256 insufficientFee = 0; // Intentionally insufficient

        // Expect the specific revert reason related to insufficient fee, and attempt to make the xsend call.
        vm.prank(recipient);
        vm.expectRevert("xERC20: insufficient fee");
        token.xsend{value: insufficientFee}(destChainId, destContract, recipient, mintAmount);

        assertEq(token.balanceOf(recipient), mintAmount, "Balance should remain unchanged");
    }
}
