// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * AuditBadge (Soulbound ERC-721)
 * - Soulbound: запрет любых трансферов и approvals
 * - Роли: DEFAULT_ADMIN_ROLE (управление ролями/ревок), AUDITOR_ROLE (минт)
 * - Уникальность: глобальная защита от дубликатов по auditHash (bytes32)
 * - Метаданные: auditURI (<= 256 байт), след сохраняется после burn (revoked = true)
 * - UX/Interop: tokenURI() (стандартное поведение), EIP-5192 locked() + Locked() on mint
 *
 * ВАЖНО: Контракт рассчитан на OpenZeppelin 4.9.x (hook _beforeTokenTransfer).
 */

import "@openzeppelin/contracts@4.9.6/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.9.6/access/AccessControl.sol";

interface IEIP5192 {
    /// @notice Emitted when a token is locked (non-transferable).
    event Locked(uint256 tokenId);
    /// @notice Emitted when a token is unlocked.
    event Unlocked(uint256 tokenId);
    /// @notice Returns true if the token is soulbound (locked).
    function locked(uint256 tokenId) external view returns (bool);
}

contract AuditBadge is ERC721, AccessControl, IEIP5192 {
    // ===== Roles =====
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    // ===== Config =====
    uint256 public constant MAX_URI_LENGTH = 256;

    // ===== Token & Data =====
    uint256 public nextTokenId;

    enum AuditLevel { Bronze, Silver, Gold }

    struct AuditInfo {
        AuditLevel level;
        bytes32    auditHash;  // keccak256 отпечаток
        string     auditURI;   // IPFS/URL (ограничен по длине)
        bool       revoked;    // пометка после burn/adminRevoke
    }

    // tokenId => audit data (сохраняем след даже после burn)
    mapping(uint256 => AuditInfo) public audits;

    // Глобальная защита от дубликатов: auditHash => уже использован?
    mapping(bytes32 => bool) public usedAuditHashes;

    // ===== Events =====
    event BadgeMinted(address indexed to, uint256 indexed tokenId, AuditLevel level, bytes32 auditHash, string auditURI);
    event BadgeBurned(uint256 indexed tokenId, address indexed byOwner);
    event BadgeRevokedByAdmin(uint256 indexed tokenId, address indexed byAdmin);

    /**
     * @param admin Адрес для DEFAULT_ADMIN_ROLE (рекомендуется мультисиг/DAO)
     * @param initialAuditors Список адресов для AUDITOR_ROLE при деплое
     */
    constructor(address admin, address[] memory initialAuditors)
        ERC721("Audit Badge", "AUD")
    {
        require(admin != address(0), "Admin is zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i = 0; i < initialAuditors.length; i++) {
            _grantRole(AUDITOR_ROLE, initialAuditors[i]);
        }
    }

    // ===== Views =====

    /// @notice Возвращает информацию об аудите; доступна и после burn (revoked=true)
    function getAudit(uint256 tokenId) external view returns (AuditInfo memory) {
        require(tokenId < nextTokenId, "Unknown tokenId");
        return audits[tokenId];
    }

    /// @notice EIP-5192: для выпущенных токенов всегда true (SBT)
    function locked(uint256 tokenId) external view returns (bool) {
        require(tokenId < nextTokenId, "Unknown tokenId");
        return true;
    }

    /// @notice Стандартный метадатный эндпоинт — возвращает auditURI только для существующих (не сожжённых) токенов
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721: invalid token ID");
        return audits[tokenId].auditURI;
    }

    // ===== Mint / Burn / Revoke =====

    /**
     * @notice Минт бейджа (только AUDITOR_ROLE).
     * @param to         Получатель
     * @param level      Bronze / Silver / Gold
     * @param auditHash  keccak256 отпечаток отчёта (bytes32)
     * @param auditURI   Короткая ссылка на артефакты (IPFS/URL), <= 256 байт
     */
    function mintBadge(
        address to,
        AuditLevel level,
        bytes32 auditHash,
        string calldata auditURI
    ) external onlyRole(AUDITOR_ROLE) {
        require(to != address(0), "To is zero");
        require(auditHash != bytes32(0), "Empty auditHash");
        uint256 uriLen = bytes(auditURI).length;
        require(uriLen > 0 && uriLen <= MAX_URI_LENGTH, "Bad URI length");

        // Глобальная уникальность
        require(!usedAuditHashes[auditHash], "Duplicate auditHash");
        usedAuditHashes[auditHash] = true;

        uint256 tokenId = nextTokenId++;

        // Пишем метаданные ДО минта (при реентранси всё откатится)
        audits[tokenId] = AuditInfo({
            level: level,
            auditHash: auditHash,
            auditURI: auditURI,
            revoked: false
        });

        _safeMint(to, tokenId);

        emit BadgeMinted(to, tokenId, level, auditHash, auditURI);
        // EIP-5192: токен изначально заблокирован (soulbound)
        emit Locked(tokenId);
    }

    /**
     * @notice Самостоятельное сжигание (ревокация) владельцем. Approvals отключены — только владелец.
     */
    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == _msgSender(), "Only owner");
        _burn(tokenId);
        audits[tokenId].revoked = true;
        emit BadgeBurned(tokenId, _msgSender());
        // Не эмитим Unlocked: токен уничтожён, а не разблокирован.
    }

    /**
     * @notice Административная ревокация (только DEFAULT_ADMIN_ROLE).
     * Рекомендуется держать эту роль на мультисиге/DAO.
     */
    function adminRevoke(uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Token not active");
        _burn(tokenId);
        audits[tokenId].revoked = true;
        emit BadgeRevokedByAdmin(tokenId, _msgSender());
    }

    // ===== Soulbound Enforcement =====

    /**
     * Запрещаем любые трансферы: разрешены только mint (from==0) и burn (to==0).
     * Проверку выполняем ДО super для экономии газа на откатах.
     * (Ориентировано на OZ 4.9.x)
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        if (from != address(0) && to != address(0)) {
            revert("Soulbound: non-transferable");
        }
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // ===== Disable approvals (гарантия против operator‑griefing) =====

    function approve(address, uint256) public pure override {
        revert("Soulbound: approvals disabled");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("Soulbound: approvals disabled");
    }

    // ===== Interfaces =====

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        // IEIP-5192: interfaceId = 0xb45a3c0e
        return interfaceId == 0xb45a3c0e || super.supportsInterface(interfaceId);
    }
}