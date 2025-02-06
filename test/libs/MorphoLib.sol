// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IMorpho, MarketParams, IMorphoStaticTyping, Id} from "morpho-blue/src/interfaces/IMorpho.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

library MorphoLib {
    function getMarketParams(bytes32 marketId, address morphoBlue) public view returns (MarketParams memory) {
        Id market = Id.wrap(marketId);

        //* Build market params
        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            IMorphoStaticTyping(morphoBlue).idToMarketParams(market);
        MarketParams memory params =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        return params;
    }
}
