// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract MidenBridgeTokenWrapper is ERC20, AccessControl {
    uint32 public immutable originNetwork;
    address public immutable originAddress;
    uint8 private _decimals;

    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor(
        string memory name_, 
        string memory symbol_,
        uint8 decimals_,
        uint32 originNetwork_,
        address originAddress_,
        address managerAddress
    ) ERC20(name_, symbol_) {
        originNetwork = originNetwork_;
        originAddress = originAddress_;
        _decimals = decimals_;
        _grantRole(BRIDGE_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, managerAddress);
        _setRoleAdmin(BRIDGE_ROLE, MANAGER_ROLE);
    }

    function decimals() public view override returns(uint8) {
        return _decimals;
    }

    function mint(address receiver, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        _mint(receiver, amount);
    }
}