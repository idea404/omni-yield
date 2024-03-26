// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "omni/contracts/src/pkg/XApp.sol";

contract OmniERC20 is ERC20, XApp {
    constructor(
        string memory name,
        string memory symbol,
        address portal
    ) ERC20(name, symbol) XApp(portal) {
        _mint(msg.sender, 100000000 * 10 ** decimals()); // 100 million tokens
    }

    /// @dev Receive tokens from another chain
    function xreceive(
        address account,
        uint256 tokens
    ) external xrecv {
        require(isXCall(), "xERC20: only xcall");
        _mint(account, tokens);
    }

    /// @dev Send tokens to another chain
    function xsend(
        uint64 destChainId,
        address destContract,
        address account,
        uint256 tokens
    ) external payable {
        require(balanceOf(msg.sender) >= tokens, "xERC20: insufficient balance");

        bytes memory data = abi.encodeWithSignature(
            "xreceive(address,uint256)",
            account,
            tokens
        );

        // calculate and enforce xcall fee
        uint256 fee = feeFor(destChainId, data);
        require(msg.value >= fee, "xERC20: insufficient fee");

        // send tokens to the contract on the destination chain
        xcall(destChainId, destContract, data);
        _burn(msg.sender, tokens);
    }
}
