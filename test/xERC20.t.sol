// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MockPortal} from "omni/contracts/test/utils/MockPortal.sol";
import {Test} from "forge-std/Test.sol";
import {xERC20} from "../src/token/xERC20.sol";

contract xERC20Test is Test {
    event TokensReceived(address indexed from, uint64 indexed fromChainId, address account, uint256 tokens);

    xERC20 token;
    MockPortal portal;
    address recipient = address(0x1);

    function setUp() public {
        portal = new MockPortal();
        token = new xERC20("Test Token", "TT", address(portal));
    }

    function testConstructor() public {
        assertEq(token.name(), "Test Token", "Name should match");
        assertEq(token.symbol(), "TT", "Symbol should match");
        assertEq(token.decimals(), 18, "Decimals should match");
    }

    function testXReceive() public {
        uint256 mintAmount = 1000 * 1e18;
        uint64 sourceChainId = 100;

        // Use portal.mockXCall to simulate an xcall to token.xreceive(...)
        portal.mockXCall(sourceChainId, address(this), address(token), abi.encodeWithSignature("xreceive(address,uint256)", recipient, mintAmount));

        assertEq(token.balanceOf(recipient), mintAmount, "Minted amount should match");
    }

    function testXSend() public payable {
        // First, simulate receiving tokens
        uint256 mintAmount = 1000 * 1e18;
        uint64 sourceChainId = 100;
        portal.mockXCall(sourceChainId, address(this), address(token), abi.encodeWithSignature("xreceive(address,uint256)", recipient, mintAmount));
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

    // Test insufficient fee for xsend
    function testXSendInsufficientFeeReverts() public {
        // First, simulate receiving tokens
        uint256 mintAmount = 1000 * 1e18;
        uint64 sourceChainId = 100;
        portal.mockXCall(sourceChainId, address(this), address(token), abi.encodeWithSignature("xreceive(address,uint256)", recipient, mintAmount));
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
    }
}