// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IMorpho, MarketParams, IMorphoStaticTyping, Id} from "morpho-blue/src/interfaces/IMorpho.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

library MorphoLib {
    address constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function getMarketParams(bytes32 marketId) public view returns (MarketParams memory) {
        Id market = Id.wrap(marketId);

        //* Build market params
        (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv) =
            IMorphoStaticTyping(MORPHO_BLUE).idToMarketParams(market);
        MarketParams memory params =
            MarketParams({loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv});

        return params;
    }
}
