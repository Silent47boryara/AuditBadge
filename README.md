# AuditBadge — Soulbound ERC-721 Audit Certificate

**AuditBadge** is a **soulbound** (non-transferable) ERC-721 token used to certify that a project has passed a smart-contract audit.  
It enforces non-transferability, disables approvals, and stores immutable audit metadata (level, report hash, URI).

---

## ✨ Features

- **Standard:** ERC-721 (OpenZeppelin 4.9.x) + optional EIP-5192 (`locked()`).
- **Access Control:**  
  - `DEFAULT_ADMIN_ROLE` (admin)  
  - `AUDITOR_ROLE` (authorized issuers)
- **Levels:** `Bronze`, `Silver`, `Gold`
- **Uniqueness:** global guard on `auditHash (bytes32)` → prevents duplicates
- **Soulbound:** transfers blocked, approvals hard-reverted

---

## 📜 Contract

Path: `contracts/AuditBadge.sol`

### Key Functions

- `mintBadge(address to, AuditLevel level, bytes32 auditHash, string auditURI)`  
  → Mint by `AUDITOR_ROLE`
- `burn(uint256 tokenId)`  
  → Owner self-revoke; metadata kept with `revoked = true`
- `adminRevoke(uint256 tokenId)`  
  → Admin emergency revoke (recommended multisig)
- `getAudit(uint256 tokenId)`  
  → Returns `{ level, auditHash, auditURI, revoked }`
- `locked(uint256 tokenId)`  
  → EIP-5192 minimal SBT (always `true`)
- `tokenURI(uint256 tokenId)`  
  → Returns stored `auditURI`

---

## 🔒 Security Notes

- **No approvals:** `approve` / `setApprovalForAll` → always revert (prevents grief burns)
- **OpenZeppelin pinned:** designed for OZ **4.9.x** (`_beforeTokenTransfer`)
- If migrating to **OZ 5.x** → adapt to `_update` hook
- Use **multisig/DAO** for `DEFAULT_ADMIN_ROLE`  
- Rotate `AUDITOR_ROLE`s via ops policy

---

## ⚡ Quickstart (Remix)

1. Open [Remix IDE](https://remix.ethereum.org/)
2. Select **Solidity Compiler** → `0.8.20` (enable Auto Compile)
3. Deploy `AuditBadge.sol` via **Injected Provider (MetaMask)** or **Remix VM**

```solidity
// Imports (pinned)
import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/access/AccessControl.sol";

// Example Mint
mintBadge(
  0xYourWalletAddress,
  2, // Gold
  0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,
  "https://example.com/audit-report.json"
);

// Metadata notes
// level: 0 = Bronze, 1 = Silver, 2 = Gold
// auditHash: keccak256 hash of the PDF/JSON audit report
// auditURI: link to the report (IPFS / Arweave / HTTPS)
```

---

## 🛠 Deployment Notes

- Designed for **OpenZeppelin 4.9.x**
- Solidity compiler: `0.8.20`
- Always use **Multisig/DAO** for `DEFAULT_ADMIN_ROLE`
- Rotate `AUDITOR_ROLE` according to ops policy

---

## 🗺 Roadmap

- Add unit tests (Hardhat / Foundry)
- IPFS integration for audit reports
- Example frontend dApp

---

## 📄 License

MIT © 2025 Silent47boryara
