// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.12;

import {IStrategyManager} from "../helpers/IStrategyManager.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {Vm} from "forge-std/Vm.sol";

library SigUtils {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Deposit {
        address strategy;
        address token;
        uint256 amount;
        address staker;
        uint256 expiry;
    }

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    struct DaiPermit {
        address owner;
        address spender;
        uint256 nonce;
        uint256 deadline;
        bool allowed;
    }

    function getDepositDigest(Deposit memory deposit, address manager) internal view returns (bytes32) {
        bytes32 DEPOSIT_TYPEHASH = keccak256(
            "Deposit(address staker,address strategy,address token,uint256 amount,uint256 nonce,uint256 expiry)"
        );
        uint256 nonce = IStrategyManager(manager).nonces(deposit.staker);
        bytes32 structHash = keccak256(
            abi.encode(
                DEPOSIT_TYPEHASH, deposit.staker, deposit.strategy, deposit.token, deposit.amount, nonce, deposit.expiry
            )
        );
        bytes32 digestHash =
            keccak256(abi.encodePacked("\x19\x01", IStrategyManager(manager).domainSeparator(), structHash));

        return digestHash;
    }

    function getPermitDigest(Permit memory permit, address token) internal view returns (bytes32) {
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, permit.owner, permit.spender, permit.value, permit.nonce, permit.deadline)
        );
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", IERC20Permit(token).DOMAIN_SEPARATOR(), structHash));

        return digestHash;
    }

    function getDaiPermitDigest(DaiPermit memory permit, address token) internal view returns (bytes32) {
        bytes32 PERMIT_TYPEHASH =
            keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, permit.owner, permit.spender, permit.nonce, permit.deadline, permit.allowed)
        );
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", IERC20Permit(token).DOMAIN_SEPARATOR(), structHash));

        return digestHash;
    }

    function sign(uint256 pk, bytes32 digest) internal pure returns (uint8, bytes32, bytes32) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return (v, r, s);
    }

    function signAggregate(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }
}
