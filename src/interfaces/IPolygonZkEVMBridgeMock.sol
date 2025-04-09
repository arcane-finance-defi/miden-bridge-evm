// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.20;

interface IPolygonZkEVMBridgeMock {
    /**
     * @dev Thrown when the destination network is invalid
     */
    error DestinationNetworkInvalid();

    /**
     * @dev Thrown when the amount does not match msg.value
     */
    error AmountDoesNotMatchMsgValue();

    /**
     * @dev Thrown when user is bridging tokens and is also sending a value
     */
    error MsgValueNotZero();

    /**
     * @dev Thrown when the Ether transfer on claimAsset fails
     */
    error EtherTransferFailed();

    /**
     * @dev Thrown when the message transaction on claimMessage fails
     */
    error MessageFailed();

    /**
     * @dev Thrown when the global exit root does not exist
     */
    error GlobalExitRootInvalid();

    /**
     * @dev Thrown when the smt proof does not match
     */
    error InvalidSmtProof();

    /**
     * @dev Thrown when an index is already claimed
     */
    error AlreadyClaimed();

    /**
     * @dev Thrown when the owner of permit does not match the sender
     */
    error NotValidOwner();

    /**
     * @dev Thrown when the spender of the permit does not match this contract address
     */
    error NotValidSpender();

    /**
     * @dev Thrown when the amount of the permit does not match
     */
    error NotValidAmount();

    /**
     * @dev Thrown when the permit data contains an invalid signature
     */
    error NotValidSignature();

    /**
     * @dev Thrown when sender is not the rollup manager
     */
    error OnlyRollupManager();

    /**
     * @dev Thrown when the permit data contains an invalid signature
     */
    error NativeTokenIsEther();

    /**
     * @dev Thrown when the permit data contains an invalid signature
     */
    error NoValueInMessagesOnGasTokenNetworks();

    /**
     * @dev Thrown when the permit data contains an invalid signature
     */
    error GasTokenNetworkMustBeZeroOnEther();

    /**
     * @dev Thrown when the wrapped token deployment fails
     */
    error FailedTokenWrappedDeployment();

    function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amount,
        address token,
        bytes calldata permitData
    ) external payable;

    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bytes calldata metadata
    ) external payable;

    function bridgeMessageWETH(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 amountWETH,
        bytes calldata metadata
    ) external;

    function initialize(
        uint32 _networkID,
        address _gasTokenAddress,
        uint32 _gasTokenNetwork,
        address bridgeAddress,
        bytes memory _gasTokenMetadata
    ) external;
}
