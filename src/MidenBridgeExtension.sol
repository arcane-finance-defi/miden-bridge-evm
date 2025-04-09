// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./PolygonZkEVMBridgeMock.sol";
import {IBridgeAndCall} from "@lxly/IBridgeAndCall.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MidenBridgeTokenWrapper.sol";


error MalformedRecipientData();
error CallAddressShouldBeZero();
error FallbackAddressShouldBeZero();
error DestinationNetworkIsNotTheMidenChain();
error AmountDoesNotMatchMsgValue();
error InvalidAddress();
error InvalidDepositIndex();
error OriginMustBeBridgeExtension();
error SenderMustBeBridge();
error UnclaimedAsset();

contract MidenBridgeExtension is IBridgeAndCall, Ownable {
    using SafeERC20 for IERC20;

    uint32 constant public MIDEN_NETWORK_ID = 9966;

    PolygonZkEVMBridgeMock public immutable bridge;
    address public immutable midenBridgeAddress;

    mapping(bytes32 => address) public wrappers;

    address public immutable managerAddress;
    
    constructor(address bridge_, bytes15 midenBridge_, address managerAddress_) {
        bridge = PolygonZkEVMBridgeMock(bridge_);
        midenBridgeAddress = address(bytes20(midenBridge_));
        managerAddress = managerAddress_;
    }
    
    function bridgeAndCall(
        address token,
        uint256 amount,
        uint32 destinationNetwork,
        address callAddress,
        address fallbackAddress,
        bytes calldata callData,
        bool _forceUpdateGlobalExitRoot
    ) external payable {
        _ensureRecipientDataValidity(callData);
        if (callAddress != address(0)) revert CallAddressShouldBeZero();
        if (fallbackAddress != address(0)) revert FallbackAddressShouldBeZero();
        if (destinationNetwork != MIDEN_NETWORK_ID) revert DestinationNetworkIsNotTheMidenChain();

        uint256 dependsOnIndex = bridge.depositCount() + 1; // only doing 1 bridge asset

        if (token != address(0) && token == address(bridge.WETHToken())) {
            // user is bridging ERC20 (WETH)
            uint256 balanceBefore = IERC20(token).balanceOf(address(this)); // WETH will only be taxable if it's modified by the chain operator

            // transfer assets from caller to this extension
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

            uint256 balanceAfter = IERC20(token).balanceOf(address(this));
            amount = balanceAfter - balanceBefore;

            // transfer the erc20 - using a helper to get rid of stack too deep
            _bridgeNativeWETHAssetHelper(
                token, amount, destinationNetwork
            );
        } else if (token == address(0)) {
            // user is bridging the gas token
            if (msg.value != amount) {
                revert AmountDoesNotMatchMsgValue();
            }

            // transfer native gas token (e.g. eth) - using a helper to get rid of stack too deep
            _bridgeNativeAssetHelper(amount, destinationNetwork);
        } else {
            // user is bridging ERC20 - beware of tax tokens
            uint256 balanceBefore = IERC20(token).balanceOf(address(this));

            // transfer assets from caller to this extension
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

            uint256 balanceAfter = IERC20(token).balanceOf(address(this));
            amount = balanceAfter - balanceBefore;

            // transfer the erc20 - using a helper to get rid of stack too deep
            _bridgeERC20AssetHelper(
                token, amount, destinationNetwork
            );
        }

        // assert that the index is correct - avoid any potential reentrancy caused by bridgeAsset
        if (dependsOnIndex != bridge.depositCount()) revert InvalidDepositIndex();

        bytes memory encodedMsg;
        if (token != address(0) && token == address(bridge.WETHToken())) {
            // WETHs originNetwork is always 0 as it is a special case
            encodedMsg =
                abi.encode(dependsOnIndex, 0, address(0), callData);
        } else if (token == address(0)) {
            // bridge the message (which gets encoded with extra data) to the extension on the destination network
            encodedMsg = abi.encode(
                dependsOnIndex,
                bridge.gasTokenNetwork(),
                bridge.gasTokenAddress(),
                callData
            );
        } else {
            // we need to encode the correct token network/address
            (uint32 assetOriginalNetwork, address assetOriginalAddr) = bridge.wrappedTokenToTokenInfo(token);
            if (assetOriginalAddr == address(0)) {
                // only do this when the token is from this network
                assetOriginalNetwork = bridge.networkID();
                assetOriginalAddr = token;
            }

            // bridge the message (which gets encoded with extra data) to the extension on the destination network
            encodedMsg = abi.encode(
                dependsOnIndex, assetOriginalNetwork, assetOriginalAddr, callData
            );
        }

        bridge.bridgeMessage(destinationNetwork, midenBridgeAddress, encodedMsg);

    }

    function _ensureRecipientDataValidity(bytes calldata callData) internal pure {
        if (callData.length != 32) revert MalformedRecipientData();
    }

    function _bridgeNativeWETHAssetHelper(
        address token,
        uint256 amount,
        uint32 destinationNetwork
    ) internal {
        // bridge the ERC20 assets - no need to approve, bridge will burn the tokens
        bridge.bridgeAsset(destinationNetwork, midenBridgeAddress, amount, token, "");
    }

    function _bridgeNativeAssetHelper(
        uint256 amount,
        uint32 destinationNetwork
    ) internal {

        // bridge the native assets
        bridge.bridgeAsset{value: amount}(destinationNetwork, midenBridgeAddress, amount, address(0), "");
    }

    function _bridgeERC20AssetHelper(
        address token,
        uint256 amount,
        uint32 destinationNetwork
    ) internal {

        {
            // we need to encode the correct token network/address
            (uint32 assetOriginalNetwork, address assetOriginalAddr) = bridge.wrappedTokenToTokenInfo(token);
            if (assetOriginalAddr == address(0)) {
                // only do this when the token is from this network
                assetOriginalNetwork = bridge.networkID();
                assetOriginalAddr = token;

                // allow the bridge to take the assets when needed - in the other scenarios the token is a wrapper that is burned
                IERC20(token).approve(address(bridge), amount);
            }
        }

        // bridge the ERC20 assets
        bridge.bridgeAsset(destinationNetwork, midenBridgeAddress, amount, token, "");
    }

    function issueToken(
        address receiver, 
        uint256 amount,
        uint32 originTokenNetwork,
        address originTokenAddress,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals
    ) external onlyOwner {
        bridge.claimAsset(
            originTokenNetwork,
            originTokenAddress,
            bridge.networkID(),
            receiver,
            amount,
            abi.encode(tokenName, tokenSymbol, tokenDecimals)
        );
    }
    
}
