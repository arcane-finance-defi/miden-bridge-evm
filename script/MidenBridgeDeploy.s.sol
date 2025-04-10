// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/PolygonZkEVMBridgeMock.sol";
import "../src/MidenBridgeExtension.sol";
import '../src/PolygonZkEVMBridgeMockProxy.sol';

contract MidenBridgeDeployScript is Script {
    function setUp() public {
    }

    function run() public {
        vm.startBroadcast();
        PolygonZkEVMBridgeMock mockBridge = new PolygonZkEVMBridgeMock();
        
        PolygonZkEVMBridgeMockProxy mockBridgeProxy = new PolygonZkEVMBridgeMockProxy(address(mockBridge), vm.envAddress("UPGRDEABLE_PROXY_ADMIN"));
        console.log("PolygonBridge proxy address: ");
        console.log(address(mockBridgeProxy));

        MidenBridgeExtension bridgeFacade = new MidenBridgeExtension(address(mockBridgeProxy), bytes15(uint120(1)), vm.envAddress("UPGRDEABLE_PROXY_ADMIN"));
        console.log("MidenBridgeExtension address:");
        console.log(address(bridgeFacade));

        address(mockBridgeProxy).call(
            abi.encodeWithSelector(
                mockBridge.initialize.selector, 
                uint32(vm.envUint("NETWORK_ID")),
                vm.envAddress("GAS_TOKEN_ADDRESS"),
                uint32(vm.envUint("GAS_TOKEN_NETWORK")),
                address(bridgeFacade),
                abi.encode("Wrapped Ethereum", "WETH", 18)
            )
        );
        vm.stopBroadcast();
    }
}
