# NEW Vulnerabilities Discovered in Security Fixes
**Date:** January 31, 2026
**Source:** Self-audit of recent changes
**Total Found:** 13 new issues

## CRITICAL Issues (3)
1. State inconsistency between tracked vs actual positions
2. Health factor division by zero risk
3. Circuit breaker creates total DoS on deposits AND withdrawals

## HIGH Issues (6)
1. Liquidation check can DoS beneficial deposits
2. Reentrancy in emergencyClosePosition()
3. TVL cap vulnerable to front-running
4. Price sanity check can permanently brick vault
5. Integer overflow in leverage calculation
6. Weak position verification (50% threshold too permissive)

## MEDIUM Issues (4)
1. Timelock bypass via proposal cycling
2. **INCORRECT PARAMETER ORDER in vault deposit** (CRITICAL BUG!)
3. First depositor uses address(1) which isn't provably unspendable
4. PnL calculation ignores funding/trading fees

## LOW Issues (2)
1. Missing event emissions
2. Approval revocation compatibility

---

**These must be fixed before deployment!**

See full audit report from agent for details.
