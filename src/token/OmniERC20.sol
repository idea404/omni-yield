// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../lib/omni/contracts/src/pkg/XApp.sol";

contract OmniERC20 is ERC20, XApp {
    mapping(uint64 => address) public chainToContract;
    uint64[] public chainIds;
    address public owner;

    constructor(
        string memory name,
        string memory symbol,
        address portal
    ) ERC20(name, symbol) XApp(portal) {
        owner = msg.sender;
        _mint(msg.sender, 100000000 * 10 ** decimals()); // 100 million tokens
        // add this contract address to the mapping
        chainToContract[omni.chainId()] = address(this);
        chainIds.push(omni.chainId());
    }

    /// @dev Set the address for a newly deployed contract on another chain
    function setChainAddress(uint64 chainId, address contractAddress) external payable {
        require(msg.sender == owner, "only owner");
        _requireSufficientFee(chainId, contractAddress);
        chainToContract[chainId] = contractAddress;
        chainIds.push(chainId);
        _broadcastMappingUpdate(chainId, contractAddress);
    }

    /// @dev Require the caller to have attached enough ETH to cover all xcalls
    function _requireSufficientFee(uint64 chainId, address contractAddress) internal {
        // Base fee for any xcall
        uint256 xcallBaseFee = feeFor(chainId, abi.encodeWithSignature("setChainAddress(uint64,address)", chainId, contractAddress));

        // Additional fee for each entry in the mapping
        uint256 feePerEntry = 50_000;

        // xcall base fee + fee per entry
        uint256 xcallFee = xcallBaseFee + feePerEntry;

        // Number of times the mapping has been updated
        uint256 timesCalled = chainIds.length;

        // Calculate the total fee based on the number of entries in the mapping
        uint256 totalFee = (xcallFee * timesCalled) + feePerEntry;

        // Require that the attached fee is at least equal to the calculated total fee
        require(msg.value >= totalFee, "insufficient fee");
    }

    /// @dev Send a mapping update to all mapped contracts
    function _broadcastMappingUpdate(uint64 chainId, address contractAddress) internal {
        for (uint256 i = 0; i < chainIds.length; i++) {
            if (chainIds[i] != omni.chainId()) {
                _sendMappingUpdate(chainIds[i], chainToContract[chainIds[i]], chainId, contractAddress);
            }
        }
    }

    /// @dev Send a mapping update to a contract on another chain
    function _sendMappingUpdate(uint64 destChainId, address destContract, uint64 chainId, address contractAddress) internal {
        bytes memory data = abi.encodeWithSignature(
            "setChainAddress(uint64,address)",
            chainId,
            contractAddress
        );
        xcall(destChainId, destContract, data);
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
