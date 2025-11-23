// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LSToken} from "./LSToken.sol";

/// @notice Deliberately vulnerable liquid staking primitive for research/CTF use only.
/// - Contains a reentrancy-unsafe withdraw flow.
/// - Uses unbounded validator loops that can be abused for gas griefing/DoS.
contract StakingManager {
    LSToken public immutable token;
    address public immutable owner;
    uint256 public totalStaked;

    struct Validator {
        address operator;
        uint256 virtualBalance; // pseudo-accounting only
        uint64 score;
    }

    Validator[] public validators;

    constructor() {
        owner = msg.sender;
        token = new LSToken("Kimchi Liquid Staked ETH", "kimLST");
    }

    receive() external payable {
        deposit();
    }

    /// @notice Anyone can spam validators; the loop in deposit/withdrawal accounting
    /// will iterate over all of them and can be forced to run out of gas.
    function registerValidator(address operator) external {
        validators.push(Validator({operator: operator, virtualBalance: 0, score: 1}));
    }

    function deposit() public payable {
        require(msg.value > 0, "no value");
        _touchValidators(msg.value);
        totalStaked += msg.value;
        token.mint(msg.sender, msg.value); // 1 wei == 1 share, no exchange rate logic
    }

    /// @dev Vulnerable: external call before burning shares allows reentrancy to drain funds.
    /// Additionally, sloppy post-call checks make it easy to skip burning after reentrancy.
    function withdraw(uint256 amount) external {
        require(amount > 0, "zero");
        require(token.balanceOf(msg.sender) >= amount, "balance");

        uint256 owed = amount;
        (bool ok,) = payable(msg.sender).call{value: owed}("");
        require(ok, "transfer failed");

        // If the user reentered and already burned, this silently skips burn + leaves stale supply.
        if (token.balanceOf(msg.sender) >= amount) {
            token.burn(msg.sender, amount);
        }
        if (totalStaked >= owed) {
            totalStaked -= owed;
        }
    }

    function validatorCount() external view returns (uint256) {
        return validators.length;
    }

    // ---- internal helpers ----

    function _touchValidators(uint256 amount) internal {
        // Unbounded storage writes; can be forced to exceed realistic gas limits.
        uint256 len = validators.length;
        for (uint256 i = 0; i < len; i++) {
            validators[i].virtualBalance += amount / (len == 0 ? 1 : len);
            validators[i].score += 1;
        }
    }
}
