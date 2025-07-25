// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GeniRewarder} from "contracts/GeniRewarder.sol";

library GeniRewarderHelper {

    function deploy(address token, address geniDex) public returns (GeniRewarder) {
        GeniRewarder impl = new GeniRewarder();
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)",
            address(this), token, geniDex);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        return GeniRewarder(payable(address(proxy)));
    }
}