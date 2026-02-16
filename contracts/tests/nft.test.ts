import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

describe("BitStack NFT Contract", () => {
  describe("Minting", () => {
    it("mints NFT for completed task", () => {
      const { result } = simnet.callPublicFn("nft", "mint-for-task", [
        Cl.principal(wallet1),
        Cl.uint(1),
        Cl.uint(1000000)
      ], deployer);
      expect(result).toBeOk(Cl.uint(1));
    });

    it("increments token ID on each mint", () => {
      simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet1), Cl.uint(1), Cl.uint(1000000)], deployer);
      const { result } = simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet2), Cl.uint(2), Cl.uint(2000000)], deployer);
      expect(result).toBeOk(Cl.uint(2));
    });
  });

  describe("Metadata", () => {
    it("stores task metadata correctly", () => {
      simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet1), Cl.uint(5), Cl.uint(3000000)], deployer);
      const { result } = simnet.callReadOnlyFn("nft", "get-token-metadata", [Cl.uint(1)], deployer);
      expect(result).toBeSome(Cl.tuple({
        "task-id": Cl.uint(5),
        "worker": Cl.principal(wallet1),
        "completed-at": Cl.uint(simnet.blockHeight),
        "reward-amount": Cl.uint(3000000)
      }));
    });

    it("returns token URI with base URI", () => {
      simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet1), Cl.uint(1), Cl.uint(1000000)], deployer);
      const { result } = simnet.callReadOnlyFn("nft", "get-token-uri", [Cl.uint(1)], deployer);
      expect(result).toBeOk(Cl.some(Cl.stringAscii("https://bitstack.io/nft/1")));
    });
  });

  describe("Ownership", () => {
    it("returns correct owner", () => {
      simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet1), Cl.uint(1), Cl.uint(1000000)], deployer);
      const { result } = simnet.callReadOnlyFn("nft", "get-owner", [Cl.uint(1)], deployer);
      expect(result).toBeOk(Cl.some(Cl.principal(wallet1)));
    });

    it("transfers NFT to new owner", () => {
      simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet1), Cl.uint(1), Cl.uint(1000000)], deployer);
      const { result } = simnet.callPublicFn("nft", "transfer", [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)], wallet1);
      expect(result).toBeOk(Cl.bool(true));
    });

    it("prevents unauthorized transfer", () => {
      simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet1), Cl.uint(1), Cl.uint(1000000)], deployer);
      const { result } = simnet.callPublicFn("nft", "transfer", [Cl.uint(1), Cl.principal(wallet1), Cl.principal(wallet2)], wallet2);
      expect(result).toBeErr(Cl.uint(101));
    });
  });

  describe("Base URI", () => {
    it("allows owner to update base URI", () => {
      const { result } = simnet.callPublicFn("nft", "set-base-uri", [Cl.stringAscii("https://new-uri.com/")], deployer);
      expect(result).toBeOk(Cl.bool(true));
    });

    it("prevents non-owner from updating base URI", () => {
      const { result } = simnet.callPublicFn("nft", "set-base-uri", [Cl.stringAscii("https://new-uri.com/")], wallet1);
      expect(result).toBeErr(Cl.uint(100));
    });
  });

  describe("Token ID", () => {
    it("returns last token ID", () => {
      simnet.callPublicFn("nft", "mint-for-task", [Cl.principal(wallet1), Cl.uint(1), Cl.uint(1000000)], deployer);
      const { result } = simnet.callReadOnlyFn("nft", "get-last-token-id", [], deployer);
      expect(result).toBeOk(Cl.uint(1));
    });
  });
});
