const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AuditBadge", function () {
  let AuditBadge, auditBadge;
  let admin, auditor, user;

  beforeEach(async function () {
    [admin, auditor, user] = await ethers.getSigners();

    // Деплой
    AuditBadge = await ethers.getContractFactory("AuditBadge");
    auditBadge = await AuditBadge.deploy();
    await auditBadge.deployed();

    // Назначаем роли
    await auditBadge.grantRole(await auditBadge.AUDITOR_ROLE(), auditor.address);
  });

  it("should mint a Gold badge", async function () {
    const auditHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes("dummy report")
    );

    await auditBadge
      .connect(auditor)
      .mintBadge(user.address, 2, auditHash, "ipfs://dummy");

    const audit = await auditBadge.getAudit(0);

    expect(audit.level).to.equal(2); // Gold
    expect(audit.revoked).to.equal(false);
    expect(audit.auditURI).to.equal("ipfs://dummy");
  });
});
