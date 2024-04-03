// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../lib/omni/contracts/src/pkg/XApp.sol";

contract xERC20 is ERC20, XApp {
    mapping(uint64 => address) public chainToContract;
    uint64[] public chainIds;
    address public admin;

    constructor(
        string memory name,
        string memory symbol,
        address portal,
        address _admin
    ) ERC20(name, symbol) XApp(portal) {
        // deploy with 0 tokens
        admin = _admin; // admin allowed to update the mapping
    }

    /// @dev Receive mapping updates from main chain
    function setChainAddress(uint64 chainId, address contractAddress) external xrecv {
        require(isXCall(), "xERC20: only xcall");
        require(xmsg.sender == admin, "xERC20: only admin");
        chainToContract[chainId] = contractAddress;
        chainIds.push(chainId);
    }

    /// @dev Receive tokens from another chain
    function xreceive(
        address account,
        uint256 tokens
    ) external xrecv {
        require(isXCall(), "xERC20: only xcall");
        require(xmsg.sender == address(this), "xERC20: only self xcall");
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
        _burn(msg.sender, tokens);

        // prepare xcall data
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
    }
}
