## Loom Loot Box Contract

Short, on-chain loot box logic with a commit/reveal flow and configurable drop tables.

### How it works
- `open-box` stores a commitment for the caller and sets a target burn block height to `burn-block-height + 1`.
- `reveal-box` checks the commitment, waits until the target burn block is reached, then derives a seed from the burn block `header-hash` plus the caller's secret.
- The seed is hashed, converted to a uint, and reduced modulo `10000` to create a roll.
- The roll maps to a tier using `common-max`, `rare-max`, and `legendary-max`, then selects an item from the matching list.

### Public functions
- `open-box (commit (buff 32))` → stores `{commit, target-height}` for `tx-sender`.
- `reveal-box (secret (buff 32))` → returns `{roll, tier, item-id, target-height}` and deletes the commitment.
- `set-owner (new-owner principal)` → owner-only.
- `set-thresholds (new-common-max uint) (new-rare-max uint) (new-legendary-max uint)` → owner-only; enforces ascending ranges and `legendary-max = 9999`.
- `set-common-items`, `set-rare-items`, `set-legendary-items` → owner-only; require non-empty lists.

### Config and storage
- `owner` defaults to `ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM`.
- Default thresholds: `common-max=8999`, `rare-max=9799`, `legendary-max=9999` (rolls are `0..9999`).
- Default item pools:
  - common: `u100 u101 u102 u103`
  - rare: `u200 u201 u202`
  - legendary: `u300 u301`
- Commitments map: `{player} -> {commit, target-height}`.

### Error codes
- `u400` bad commit
- `u401` not authorized
- `u404` not found
- `u409` already committed
- `u412` not ready
- `u422` empty pool / bad config
