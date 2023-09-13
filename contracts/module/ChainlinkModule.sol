// SPDX-License-Identifier: UNLICENSED
/*

                         ┌───────────┐
                         │ HOLOGRAPH │
                         └───────────┘
╔═════════════════════════════════════════════════════════════╗
║                                                             ║
║                            / ^ \                            ║
║                            ~~*~~            ¸               ║
║                         [ '<>:<>' ]         │░░░            ║
║               ╔╗           _/"\_           ╔╣               ║
║             ┌─╬╬─┐          """          ┌─╬╬─┐             ║
║          ┌─┬┘ ╠╣ └┬─┐       \_/       ┌─┬┘ ╠╣ └┬─┐          ║
║       ┌─┬┘ │  ╠╣  │ └┬─┐           ┌─┬┘ │  ╠╣  │ └┬─┐       ║
║    ┌─┬┘ │  │  ╠╣  │  │ └┬─┐     ┌─┬┘ │  │  ╠╣  │  │ └┬─┐    ║
║ ┌─┬┘ │  │  │  ╠╣  │  │  │ └┬┐ ┌┬┘ │  │  │  ╠╣  │  │  │ └┬─┐ ║
╠┬┘ │  │  │  │  ╠╣  │  │  │  │└¤┘│  │  │  │  ╠╣  │  │  │  │ └┬╣
║│  │  │  │  │  ╠╣  │  │  │  │   │  │  │  │  ╠╣  │  │  │  │  │║
╠╩══╩══╩══╩══╩══╬╬══╩══╩══╩══╩═══╩══╩══╩══╩══╬╬══╩══╩══╩══╩══╩╣
╠┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╬╬┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴╣
║               ╠╣                           ╠╣               ║
║               ╠╣                           ╠╣               ║
║    ,          ╠╣     ,        ,'      *    ╠╣               ║
║~~~~~^~~~~~~~~┌╬╬┐~~~^~~~~~~~~^^~~~~~~~~^~~┌╬╬┐~~~~~~~^~~~~~~║
╚══════════════╩╩╩╩═════════════════════════╩╩╩╩══════════════╝
     - one protocol, one bridge = infinite possibilities -


 ***************************************************************

 DISCLAIMER: U.S Patent Pending

 LICENSE: Holograph Limited Public License (H-LPL)

 https://holograph.xyz/licenses/h-lpl/1.0.0

 This license governs use of the accompanying software. If you
 use the software, you accept this license. If you do not accept
 the license, you are not permitted to use the software.

 1. Definitions

 The terms "reproduce," "reproduction," "derivative works," and
 "distribution" have the same meaning here as under U.S.
 copyright law. A "contribution" is the original software, or
 any additions or changes to the software. A "contributor" is
 any person that distributes its contribution under this
 license. "Licensed patents" are a contributor’s patent claims
 that read directly on its contribution.

 2. Grant of Rights

 A) Copyright Grant- Subject to the terms of this license,
 including the license conditions and limitations in sections 3
 and 4, each contributor grants you a non-exclusive, worldwide,
 royalty-free copyright license to reproduce its contribution,
 prepare derivative works of its contribution, and distribute
 its contribution or any derivative works that you create.
 B) Patent Grant- Subject to the terms of this license,
 including the license conditions and limitations in section 3,
 each contributor grants you a non-exclusive, worldwide,
 royalty-free license under its licensed patents to make, have
 made, use, sell, offer for sale, import, and/or otherwise
 dispose of its contribution in the software or derivative works
 of the contribution in the software.

 3. Conditions and Limitations

 A) No Trademark License- This license does not grant you rights
 to use any contributors’ name, logo, or trademarks.
 B) If you bring a patent claim against any contributor over
 patents that you claim are infringed by the software, your
 patent license from such contributor is terminated with
 immediate effect.
 C) If you distribute any portion of the software, you must
 retain all copyright, patent, trademark, and attribution
 notices that are present in the software.
 D) If you distribute any portion of the software in source code
 form, you may do so only under this license by including a
 complete copy of this license with your distribution. If you
 distribute any portion of the software in compiled or object
 code form, you may only do so under a license that complies
 with this license.
 E) The software is licensed “as-is.” You bear all risks of
 using it. The contributors give no express warranties,
 guarantees, or conditions. You may have additional consumer
 rights under your local laws which this license cannot change.
 To the extent permitted under your local laws, the contributors
 exclude all implied warranties, including those of
 merchantability, fitness for a particular purpose and
 non-infringement.

 4. (F) Platform Limitation- The licenses granted in sections
 2.A & 2.B extend only to the software or derivative works that
 you create that run on a Holograph system product.

 ***************************************************************

*/

pragma solidity 0.8.13;

import "../abstract/Admin.sol";
import "../abstract/Initializable.sol";

import "../enum/ChainIdType.sol";

import "../interface/CrossChainMessageInterface.sol";
import "../interface/HolographOperatorInterface.sol";
import "../interface/InitializableInterface.sol";
import "../interface/HolographInterfacesInterface.sol";
import "../interface/ChainlinkModuleInterface.sol";
// import "../interface/ChainlinkOverrides.sol"; // TODO: Not sure if this is needed yet

import "../interface/IRouterClient.sol";
import "../interface/IAny2EVMMessageReceiver.sol";
import "../interface/ERC20.sol";

import "../library/Client.sol";

import "../struct/GasParameters.sol";

import "./OVM_GasPriceOracle.sol";

/**
 * @title Holograph Chainlink Module
 * @author https://github.com/holographxyz
 * @notice Holograph module for enabling Chainlink cross-chain messaging
 * @dev This contract abstracts all of the Chainlink specific logic into an isolated module
 */
contract ChainlinkModule is
  Admin,
  Initializable,
  IAny2EVMMessageReceiver,
  CrossChainMessageInterface,
  ChainlinkModuleInterface
{
  //////////////////////////////////////////////////////////////////////////////////////////////////////
  // Holograph Variables ///////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////
  /**z
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.bridge')) - 1)
   */
  bytes32 constant _bridgeSlot = 0xeb87cbb21687feb327e3d58c6c16d552231d12c7a0e8115042a4165fac8a77f9;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.interfaces')) - 1)
   */
  bytes32 constant _interfacesSlot = 0xbd3084b8c09da87ad159c247a60e209784196be2530cecbbd8f337fdd1848827;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.chainlinkEndpoint')) - 1)
   */
  bytes32 constant _chainlinkEndpointSlot = 0x689c34cc186253d10c53ee2705ae99837faecca7a292d73da3a7580e0b90b02b;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.operator')) - 1)
   */
  bytes32 constant _operatorSlot = 0x7caba557ad34138fa3b7e43fb574e0e6cc10481c3073e0dffbc560db81b5c60f;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.gasParameters')) - 1)
   */
  bytes32 constant _gasParametersSlot = 0x15eee82a0af3c04e4b65c3842105c973a6b0fb2a68728bf035809e13b38ce8cf;
  /**
   * @dev bytes32(uint256(keccak256('eip1967.Holograph.gasParameters')) - 1)
   */
  bytes32 constant _optimismGasPriceOracleSlot = 0x46043c284a96474ab4a54c741ea0d0fce54e98eea878b99d4b85808fa6f71a5f;

  //////////////////////////////////////////////////////////////////////////////////////////////////////
  // CCIP Variables ////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////
  /**
   * @dev This is the address of the Chainlink Endpoint that is approved to send cross-chain messages
   */
  address internal i_router;
  bytes32 private lastReceivedMessageId; // Store the last received messageId.
  string private lastReceivedText; // Store the last received text.

  //////////////////////////////////////////////////////////////////////////////////////////////////////
  // Errors ////////////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////

  error InvalidRouter(address router);
  error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.
  error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
  error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
  error DestinationChainNotWhitelisted(uint64 destinationChainSelector); // Used when the destination chain has not been whitelisted by the contract owner.
  error SourceChainNotWhitelisted(uint64 sourceChainSelector); // Used when the source chain has not been whitelisted by the contract owner.
  error SenderNotWhitelisted(address sender); // Used when the sender has not been whitelisted by the contract owner.

  //////////////////////////////////////////////////////////////////////////////////////////////////////
  // Modifiers /////////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev only calls from the set router are accepted.
  modifier onlyRouter() {
    if (msg.sender != address(i_router)) revert InvalidRouter(msg.sender);
    _;
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////
  // Events ////////////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////

  // TODO: Events are taken from CCIP Documentation. They might need to be updated to fit Holograph needs
  // Event emitted when a message is sent to another chain.
  event MessageSent(
    bytes32 indexed messageId, // The unique ID of the CCIP message.
    uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
    address receiver, // The address of the receiver on the destination chain.
    string text, // The text being sent.
    address feeToken, // the token address used to pay CCIP fees.
    uint256 fees // The fees paid for sending the CCIP message.
  );

  // Event emitted when a message is received from another chain.
  event MessageReceived(
    bytes32 indexed messageId, // The unique ID of the CCIP message.
    uint64 indexed sourceChainSelector, // The chain selector of the source chain.
    address sender, // The address of the sender from the source chain.
    string text // The text that was received.
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @dev Constructor is left empty and init is used instead
   */
  constructor() {}

  /**
   * @notice Used internally to initialize the contract instead of through a constructor
   * @dev This function is called by the deployer/factory when creating a contract
   * @param initPayload abi encoded payload to use for contract initilaization
   */
  function init(bytes memory initPayload) external override returns (bytes4) {
    require(!_isInitialized(), "HOLOGRAPH: already initialized");
    (
      address router,
      address bridge,
      address interfaces,
      address operator,
      address optimismGasPriceOracle,
      uint32[] memory chainIds,
      GasParameters[] memory gasParameters
    ) = abi.decode(initPayload, (address, address, address, address, address, uint32[], GasParameters[]));
    assembly {
      sstore(_adminSlot, origin())
      sstore(_bridgeSlot, bridge)
      sstore(_interfacesSlot, interfaces)
      sstore(_operatorSlot, operator)
      sstore(_optimismGasPriceOracleSlot, optimismGasPriceOracle)
    }

    // Set the default gas parameters
    require(chainIds.length == gasParameters.length, "HOLOGRAPH: wrong array lengths");
    for (uint256 i = 0; i < chainIds.length; i++) {
      _setGasParameters(chainIds[i], gasParameters[i]);
    }

    // Set the router
    if (router == address(0)) revert InvalidRouter(address(0));
    i_router = router;

    _setInitialized();
    return InitializableInterface.init.selector;
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////
  // CCIPReceiver //////////////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////

  // TODO: Think about how to add 165 Support
  // /// @notice IERC165 supports an interfaceId
  // /// @param interfaceId The interfaceId to check
  // /// @return true if the interfaceId is supported
  // function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
  //   return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  // }

  /// @inheritdoc IAny2EVMMessageReceiver
  function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
    _ccipReceive(message);
  }

  // NOTE: Since this contract is acting as the CCIPReceiver, we only need to implement the _ccipReceive function instead
  /// @notice Override this function in your implementation.
  /// @param message Any2EVMMessage
  // function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual;

  /// @notice Return the current router
  /// @return i_router address
  function getRouter() public view returns (address) {
    return address(i_router);
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////
  // Core CCIP Functions ///////////////////////////////////////////////////////////////////////////////
  //////////////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Sends data to receiver on the destination chain.
  /// @notice Pay for fees in native gas.
  /// @dev Assumes your contract has sufficient native gas tokens.
  /// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
  /// @param _receiver The address of the recipient on the destination blockchain.
  /// @param _text The text to be sent.
  /// @return messageId The ID of the CCIP message that was sent.
  function sendMessagePayNative(
    uint64 _destinationChainSelector,
    address _receiver,
    string calldata _text
  ) external onlyAdmin /*onlyWhitelistedDestinationChain(_destinationChainSelector)*/ returns (bytes32 messageId) {
    // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
    Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_receiver, _text, address(0));

    // Initialize a router client instance to interact with cross-chain router
    IRouterClient router = IRouterClient(this.getRouter());

    // Get the fee required to send the CCIP message
    uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

    if (fees > address(this).balance) revert NotEnoughBalance(address(this).balance, fees);

    // Send the CCIP message through the router and store the returned CCIP message ID
    messageId = router.ccipSend{value: fees}(_destinationChainSelector, evm2AnyMessage);

    // Emit an event with message details
    emit MessageSent(messageId, _destinationChainSelector, _receiver, _text, address(0), fees);

    // Return the CCIP message ID
    return messageId;
  }

  /// Handle a received message
  function _ccipReceive(
    Client.Any2EVMMessage memory any2EvmMessage // override // onlyWhitelistedSourceChain(any2EvmMessage.sourceChainSelector) // Make sure source chain is whitelisted
  )
    internal
  // onlyWhitelistedSenders(abi.decode(any2EvmMessage.sender, (address))) // Make sure the sender is whitelisted
  {
    lastReceivedMessageId = any2EvmMessage.messageId; // fetch the messageId
    lastReceivedText = abi.decode(any2EvmMessage.data, (string)); // abi-decoding of the sent text

    emit MessageReceived(
      any2EvmMessage.messageId,
      any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
      abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
      abi.decode(any2EvmMessage.data, (string))
    );
  }

  /// @notice Construct a CCIP message.
  /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for sending a text.
  /// @param _receiver The address of the receiver.
  /// @param _text The string data to be sent.
  /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
  /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
  function _buildCCIPMessage(
    address _receiver,
    string calldata _text,
    address _feeTokenAddress
  ) internal pure returns (Client.EVM2AnyMessage memory) {
    // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
    Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
      receiver: abi.encode(_receiver), // ABI-encoded receiver address
      data: abi.encode(_text), // ABI-encoded string
      tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
      extraArgs: Client._argsToBytes(
        // Additional arguments, setting gas limit and non-strict sequencing mode
        Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
      ),
      // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
      feeToken: _feeTokenAddress
    });
    return evm2AnyMessage;
  }

  /// @notice Fetches the details of the last received message.
  /// @return messageId The ID of the last received message.
  /// @return text The last received text.
  function getLastReceivedMessageDetails() external view returns (bytes32 messageId, string memory text) {
    return (lastReceivedMessageId, lastReceivedText);
  }

  /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
  /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
  /// It should only be callable by the owner of the contract.
  /// @param _beneficiary The address to which the Ether should be sent.
  function withdraw(address _beneficiary) public onlyAdmin {
    // Retrieve the balance of this contract
    uint256 amount = address(this).balance;

    // Revert if there is nothing to withdraw
    if (amount == 0) revert NothingToWithdraw();

    // Attempt to send the funds, capturing the success status and discarding any return data
    (bool sent, ) = _beneficiary.call{value: amount}("");

    // Revert if the send failed, with information about the attempted transfer
    if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
  }

  /// @notice Allows the owner of the contract to withdraw all tokens of a specific ERC20 token.
  /// @dev This function reverts with a 'NothingToWithdraw' error if there are no tokens to withdraw.
  /// @param _beneficiary The address to which the tokens will be sent.
  /// @param _token The contract address of the ERC20 token to be withdrawn.
  function withdrawToken(address _beneficiary, address _token) public onlyAdmin {
    // Retrieve the balance of this contract
    uint256 amount = ERC20(_token).balanceOf(address(this));

    // Revert if there is nothing to withdraw
    if (amount == 0) revert NothingToWithdraw();

    ERC20(_token).transfer(_beneficiary, amount);
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Receive cross-chain message from Chainlink
   * @dev This function only allows calls from the configured Chainlink endpoint address
   */
  function chainlinkReceive(
    uint16 /* _srcChainId*/,
    bytes calldata _srcAddress,
    uint64 /* _nonce*/,
    bytes calldata _payload
  ) external payable {
    assembly {
      /**
       * @dev check if msg.sender is Chainlink Endpoint
       */
      switch eq(sload(_chainlinkEndpointSlot), caller())
      case 0 {
        /**
         * @dev this is the assembly version of -> revert("HOLOGRAPH: Chainlink only endpoint");
         */
        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0xa0, 0x0000002400000000000000000000000000000000000000000000000000000000)
        mstore(0xc0, 0x484f4c4f47524150483a20436861696e6c696e6b206f6e6c7920656e64706f)
        mstore(0xe0, 0x696e740000000000000000000000000000000000000000000000000000000000)
        revert(0x80, 0x48)
      }
      let ptr := mload(0x40)
      calldatacopy(add(ptr, 0x0c), _srcAddress.offset, _srcAddress.length)
      /**
       * @dev check if Chainlink from address is same as address(this)
       */
      switch eq(mload(ptr), address())
      case 0 {
        /**
         * @dev this is the assembly version of -> revert("HOLOGRAPH: unauthorized sender");
         */
        mstore(0x80, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0xa0, 0x0000002000000000000000000000000000000000000000000000000000000000)
        mstore(0xc0, 0x0000001e484f4c4f47524150483a20756e617574686f72697a65642073656e64)
        mstore(0xe0, 0x6572000000000000000000000000000000000000000000000000000000000000)
        revert(0x80, 0xc4)
      }
    }
    /**
     * @dev if validation has passed, submit payload to Holograph Operator for converting into an operator job
     */
    _operator().crossChainMessage(_payload);
  }

  // TODO: ALL OF THE CHAINLINK FUNCTIONS NEED AND GAS CALCUATIONS NEED TO BE REWORKED TO FIT CCIP INSTEAD OF LZ
  // /**
  //  * @dev Need to add an extra function to get Chainlink gas amount needed for their internal cross-chain message verification
  //  */
  // function send(
  //   uint256 /* gasLimit*/,
  //   uint256 /* gasPrice*/,
  //   uint32 toChain,
  //   address msgSender,
  //   uint256 msgValue,
  //   bytes calldata crossChainPayload
  // ) external payable {
  //   require(msg.sender == address(_operator()), "HOLOGRAPH: operator only call");
  //   ChainlinkOverrides chainlinkEndpoint;
  //   assembly {
  //     chainlinkEndpoint := sload(_chainlinkEndpointSlot)
  //   }
  //   GasParameters memory gasParameters = _gasParameters(toChain);
  //   // need to recalculate the gas amounts for Chainlink to deliver message
  //   chainlinkEndpoint.send{value: msgValue}(
  //     uint16(_interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.CHAINLINK)),
  //     abi.encodePacked(address(this), address(this)),
  //     crossChainPayload,
  //     payable(msgSender),
  //     address(this),
  //     abi.encodePacked(
  //       uint16(1),
  //       uint256(gasParameters.msgBaseGas + (crossChainPayload.length * gasParameters.msgGasPerByte))
  //     )
  //   );
  // }

  // function getMessageFee(
  //   uint32 toChain,
  //   uint256 gasLimit,
  //   uint256 gasPrice,
  //   bytes calldata crossChainPayload
  // ) external view returns (uint256 hlgFee, uint256 msgFee, uint256 dstGasPrice) {
  //   uint16 chainlinkDestChain = uint16(
  //     _interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.CHAIN)
  //   );
  //   ChainlinkOverrides chainlinkEndpoint;
  //   assembly {
  //     chainlinkEndpoint := sload(_chainlinkEndpointSlot)
  //   }
  //   // convert holograph chain id to chainlinkEndpoint chain id
  //   (uint128 dstPriceRatio, uint128 dstGasPriceInWei) = _getPricing(chainlinkEndpoint, chainlinkDestChain);
  //   if (gasPrice == 0) {
  //     gasPrice = dstGasPriceInWei;
  //   }
  //   GasParameters memory gasParameters = _gasParameters(toChain);
  //   require(gasPrice > gasParameters.minGasPrice, "HOLOGRAPH: gas price too low");
  //   bytes memory adapterParams = abi.encodePacked(
  //     uint16(1),
  //     uint256(gasParameters.msgBaseGas + (crossChainPayload.length * gasParameters.msgGasPerByte))
  //   );
  //   gasLimit = gasLimit + gasParameters.jobBaseGas + (crossChainPayload.length * gasParameters.jobGasPerByte);
  //   gasLimit = gasLimit + (gasLimit / 10);
  //   require(gasLimit < gasParameters.maxGasLimit, "HOLOGRAPH: gas limit over max");
  //   (uint256 nativeFee, ) = chainlinkEndpoint.estimateFees(
  //     chainlinkDestChain,
  //     address(this),
  //     crossChainPayload,
  //     false,
  //     adapterParams
  //   );
  //   hlgFee = ((gasPrice * gasLimit) * dstPriceRatio) / (10 ** 20);
  //   /*
  //    * @dev toChain is a ChainIdType.HOLOGRAPH, which can be found at https://github.com/holographxyz/networks/blob/main/src/networks.ts
  //    *      chainId 7 == optimism
  //    *      chainId 4000000015 == optimismTestnetGoerli
  //    */
  //   if (toChain == uint32(7) || toChain == uint32(4000000015)) {
  //     hlgFee += (_optimismGasPriceOracle().getL1Fee(crossChainPayload) * dstPriceRatio) / (10 ** 20);
  //   }
  //   msgFee = nativeFee;
  //   dstGasPrice = (dstGasPriceInWei * dstPriceRatio) / (10 ** 20);
  // }

  // function getHlgFee(
  //   uint32 toChain,
  //   uint256 gasLimit,
  //   uint256 gasPrice,
  //   bytes calldata crossChainPayload
  // ) external view returns (uint256 hlgFee) {
  //   ChainlinkOverrides chainlinkEndpoint;
  //   assembly {
  //     chainlinkEndpoint := sload(_chainlinkEndpointSlot)
  //   }
  //   uint16 chainlinkDestChain = uint16(
  //     _interfaces().getChainId(ChainIdType.HOLOGRAPH, uint256(toChain), ChainIdType.CHAIN)
  //   );
  //   (uint128 dstPriceRatio, uint128 dstGasPriceInWei) = _getPricing(chainlinkEndpoint, chainlinkDestChain);
  //   if (gasPrice == 0) {
  //     gasPrice = dstGasPriceInWei;
  //   }
  //   GasParameters memory gasParameters = _gasParameters(toChain);
  //   require(gasPrice > gasParameters.minGasPrice, "HOLOGRAPH: gas price too low");
  //   gasLimit = gasLimit + gasParameters.jobBaseGas + (crossChainPayload.length * gasParameters.jobGasPerByte);
  //   gasLimit = gasLimit + (gasLimit / 10);
  //   require(gasLimit < gasParameters.maxGasLimit, "HOLOGRAPH: gas limit over max");
  //   hlgFee = ((gasPrice * gasLimit) * dstPriceRatio) / (10 ** 20);
  //   /*
  //    * @dev toChain is a ChainIdType.HOLOGRAPH, which can be found at https://github.com/holographxyz/networks/blob/main/src/networks.ts
  //    *      chainId 7 == optimism
  //    *      chainId 4000000015 == optimismTestnetGoerli
  //    */
  //   if (toChain == uint32(7) || toChain == uint32(4000000015)) {
  //     hlgFee += (_optimismGasPriceOracle().getL1Fee(crossChainPayload) * dstPriceRatio) / (10 ** 20);
  //   }
  // }

  // function _getPricing(
  //   ChainlinkOverrides chainlinkEndpoint,
  //   uint16 chainlinkDestChain
  // ) private view returns (uint128 dstPriceRatio, uint128 dstGasPriceInWei) {
  //   return
  //     ChainlinkOverrides(
  //       ChainlinkOverrides(chainlinkEndpoint.defaultSendLibrary())
  //         .getAppConfig(chainlinkDestChain, address(this))
  //         .relayer
  //     ).dstPriceLookup(chainlinkDestChain);
  // }

  // These are the functions that need to be implemented for the CrossChainMessageInterface
  // Here temporarily until we can figure out how to implement them for Chainlink
  function send(
    uint256 gasLimit,
    uint256 gasPrice,
    uint32 toChain,
    address msgSender,
    uint256 msgValue,
    bytes calldata crossChainPayload
  ) external payable override {
    // TODO: Implement this
  }

  function getMessageFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view override returns (uint256 hlgFee, uint256 msgFee, uint256 dstGasPrice) {
    return (0, 0, 0); // TODO: Implement this
  }

  function getHlgFee(
    uint32 toChain,
    uint256 gasLimit,
    uint256 gasPrice,
    bytes calldata crossChainPayload
  ) external view override returns (uint256 hlgFee) {
    return 0; // TODO: Implement this
  }

  /**
   * @notice Get the address of the Holograph Bridge module
   * @dev Used for beaming holographable assets cross-chain
   */
  function getBridge() external view returns (address bridge) {
    assembly {
      bridge := sload(_bridgeSlot)
    }
  }

  /**
   * @notice Update the Holograph Bridge module address
   * @param bridge address of the Holograph Bridge smart contract to use
   */
  function setBridge(address bridge) external onlyAdmin {
    assembly {
      sstore(_bridgeSlot, bridge)
    }
  }

  /**
   * @notice Get the address of the Holograph Interfaces module
   * @dev Holograph uses this contract to store data that needs to be accessed by a large portion of the modules
   */
  function getInterfaces() external view returns (address interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  /**
   * @notice Update the Holograph Interfaces module address
   * @param interfaces address of the Holograph Interfaces smart contract to use
   */
  function setInterfaces(address interfaces) external onlyAdmin {
    assembly {
      sstore(_interfacesSlot, interfaces)
    }
  }

  /**
   * @notice Get the address of the approved Chainlink Endpoint
   * @dev All chainlinkReceive function calls allow only requests from this address
   */
  function getChainlinkEndpoint() external view returns (address chainlinkEndpoint) {
    assembly {
      chainlinkEndpoint := sload(_chainlinkEndpointSlot)
    }
  }

  /**
   * @notice Update the approved Chainlink Endpoint address
   * @param chainlinkEndpoint address of the Chainlink Endpoint to use
   */
  function setChainlinkEndpoint(address chainlinkEndpoint) external onlyAdmin {
    assembly {
      sstore(_chainlinkEndpointSlot, chainlinkEndpoint)
    }
  }

  /**
   * @notice Get the address of the Holograph Operator module
   * @dev All cross-chain Holograph Bridge beams are handled by the Holograph Operator module
   */
  function getOperator() external view returns (address operator) {
    assembly {
      operator := sload(_operatorSlot)
    }
  }

  /**
   * @notice Update the Holograph Operator module address
   * @param operator address of the Holograph Operator smart contract to use
   */
  function setOperator(address operator) external onlyAdmin {
    assembly {
      sstore(_operatorSlot, operator)
    }
  }

  /**
   * @notice Get the address of the Optimism Gas Price Oracle module
   * @dev Allows to properly calculate the L1 security fee for Optimism bridge transactions
   */
  function getOptimismGasPriceOracle() external view returns (address optimismGasPriceOracle) {
    assembly {
      optimismGasPriceOracle := sload(_optimismGasPriceOracleSlot)
    }
  }

  /**
   * @notice Update the Optimism Gas Price Oracle module address
   * @param optimismGasPriceOracle address of the Optimism Gas Price Oracle smart contract to use
   */
  function setOptimismGasPriceOracle(address optimismGasPriceOracle) external onlyAdmin {
    assembly {
      sstore(_optimismGasPriceOracleSlot, optimismGasPriceOracle)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Bridge Interface
   */
  function _bridge() private view returns (address bridge) {
    assembly {
      bridge := sload(_bridgeSlot)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Interfaces Interface
   */
  function _interfaces() private view returns (HolographInterfacesInterface interfaces) {
    assembly {
      interfaces := sload(_interfacesSlot)
    }
  }

  /**
   * @dev Internal function used for getting the Holograph Operator Interface
   */
  function _operator() private view returns (HolographOperatorInterface operator) {
    assembly {
      operator := sload(_operatorSlot)
    }
  }

  /**
   * @dev Internal function used for getting the Optimism Gas Price Oracle Interface
   */
  function _optimismGasPriceOracle() private view returns (OVM_GasPriceOracle optimismGasPriceOracle) {
    assembly {
      optimismGasPriceOracle := sload(_optimismGasPriceOracleSlot)
    }
  }

  /**
   * @dev Purposefully reverts to prevent having any type of ether transfered into the contract
   */
  // receive() external payable {
  //   revert();
  // }

  /**
   * @dev CCIP Requires the contract to be fundable
   */
  receive() external payable {}

  /**
   * @dev Purposefully reverts to prevent any calls to undefined functions
   */
  fallback() external payable {
    revert();
  }

  /**
   * @notice Get the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to get gas parameters for, set to 0 for default
   */
  function getGasParameters(uint32 chainId) external view returns (GasParameters memory gasParameters) {
    return _gasParameters(chainId);
  }

  /**
   * @notice Update the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to set gas parameters for, set to 0 for default
   * @param gasParameters struct of all the gas parameters to set
   */
  function setGasParameters(uint32 chainId, GasParameters memory gasParameters) external onlyAdmin {
    _setGasParameters(chainId, gasParameters);
  }

  /**
   * @notice Update the default or chain-specific GasParameters
   * @param chainIds array of Holograph ChainId to set gas parameters for
   * @param gasParameters array of all the gas parameters to set
   */
  function setGasParameters(uint32[] memory chainIds, GasParameters[] memory gasParameters) external onlyAdmin {
    require(chainIds.length == gasParameters.length, "HOLOGRAPH: wrong array lengths");
    for (uint256 i = 0; i < chainIds.length; i++) {
      _setGasParameters(chainIds[i], gasParameters[i]);
    }
  }

  /**
   * @notice Internal function for setting the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to set gas parameters for, set to 0 for default
   * @param gasParameters struct of all the gas parameters to set
   */
  function _setGasParameters(uint32 chainId, GasParameters memory gasParameters) private {
    bytes32 slot = chainId == 0 ? _gasParametersSlot : keccak256(abi.encode(chainId, _gasParametersSlot));
    assembly {
      let pos := gasParameters
      for {
        let i := 0
      } lt(i, 6) {
        i := add(i, 1)
      } {
        sstore(add(slot, i), mload(pos))
        pos := add(pos, 32)
      }
    }
  }

  /**
   * @dev Internal function used for getting the default or chain-specific GasParameters
   * @param chainId the Holograph ChainId to get gas parameters for, set to 0 for default
   */
  function _gasParameters(uint32 chainId) private view returns (GasParameters memory gasParameters) {
    bytes32 slot = chainId == 0 ? _gasParametersSlot : keccak256(abi.encode(chainId, _gasParametersSlot));
    assembly {
      let pos := gasParameters
      for {
        let i := 0
      } lt(i, 6) {
        i := add(i, 1)
      } {
        mstore(pos, sload(add(slot, i)))
        pos := add(pos, 32)
      }
    }
  }
}
