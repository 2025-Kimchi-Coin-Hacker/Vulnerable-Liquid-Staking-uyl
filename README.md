# Vulnerable-Liquid-Staking-uyl

Deliberately insecure liquid staking primitive built for research/CTF. The core pieces are:

- `src/StakingManager.sol` – accepts ETH deposits, mints LST shares, tracks a validator registry, and exposes a reentrancy-unsafe withdrawal flow.
- `src/LSToken.sol` – minimal ERC20-like share token minted/burned by the manager.

## Included vulnerabilities

- **Reentrancy on withdraw**: `withdraw()` sends ETH before burning shares. A malicious receiver can reenter and drain multiple times while balances are unchanged; sloppy post-call checks skip burning after reentrancy.
- **Unbounded validator loops (gas DoS)**: `registerValidator()` is permissionless and every deposit iterates+touches the entire `validators` array with storage writes, so a spammer can create enough entries to make user deposits revert under realistic gas limits.

## Quick start

```bash
forge install
forge test -vv
```

Key demos:
- `forge test -m testReentrancyDrain` shows a reentrancy attacker extracting more ETH than staked.
- `forge test -m testValidatorLoopDoS` shows deposits failing when the validator list is spammed and gas is capped.

## Checklist mapping

| Check | Status / how to trigger |
| --- | --- |
| Reentrancy during withdrawal | Present. `StakingManager.withdraw` calls external before effects; see `testReentrancyDrain`. |
| Loops / out-of-gas on large arrays | Present. Unbounded validator iteration in `deposit`; see `testValidatorLoopDoS`. |
| Deterministic withdrawal vault address calculations | Not implemented (useful future exercise). |
| Beacon chain state root manipulation | Not implemented. |
| Economic attacks on token value | Not implemented (price is naive 1:1). |
| Preventing slashing | Not implemented (no slashing logic). |
| Merkle proofs spoofing | Not implemented. |
| Handling decimals in calculations | Not hardened; 1 wei = 1 share assumption leaves room for pricing errors but not demonstrated here. |

> This code is intentionally unsafe and should never be deployed to mainnet.
