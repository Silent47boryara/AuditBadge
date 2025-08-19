# AuditBadge — Soulbound ERC‑721 Audit Certificate

**AuditBadge** is a soulbound (non‑transferable) ERC‑721 token used to certify that a project has passed a smart‑contract audit.  
It enforces non‑transferability, disables approvals, and stores immutable audit metadata (level, report hash, URI).

- Standard: **ERC‑721 (OpenZeppelin 4.9.x)** + optional **EIP‑5192** interface (`locked()`).
- Access control: `DEFAULT_ADMIN_ROLE` (admin), `AUDITOR_ROLE` (authorized issuers).
- Levels: `Bronze`, `Silver`, `Gold`.
- Uniqueness: global guard on `auditHash` (`bytes32`) to prevent duplicates.
- Soulbound: transfers are blocked; approvals are hard‑reverted.

## Contract

`contracts/AuditBadge.sol`

Key functions:
- `mintBadge(address to, AuditLevel level, bytes32 auditHash, string auditURI)` — mint by `AUDITOR_ROLE`.
- `burn(uint256 tokenId)` — owner self‑revoke; metadata kept with `revoked=true`.
- `adminRevoke(uint256 tokenId)` — admin emergency revoke (recommended multisig).
- `getAudit(uint256 tokenId)` — returns `{ level, auditHash, auditURI, revoked }`.
- `locked(uint256 tokenId)` — EIP‑5192 minimal SBT (always `true` for minted IDs).
- `tokenURI(uint256 tokenId)` — returns the stored `auditURI`.

## Security Notes

- **No approvals** (`approve` / `setApprovalForAll` revert) → prevents operator‑based grief burns.
- **OZ version pinned**: designed for OpenZeppelin **4.9.x** hook (`_beforeTokenTransfer`).  
  If you migrate to OZ 5.x, adapt to the new `_update` hook.
- Use a **multisig/DAO** for `DEFAULT_ADMIN_ROLE`. Rotate `AUDITOR_ROLE`s via ops policy.

## Compile & Deploy (Remix quickstart)

1. Compiler **0.8.20**; enable **Auto compile**.
2. Imports (pinned):
   ```solidity
   import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
   import "@openzeppelin/contracts@4.9.6/access/AccessControl.sol";
