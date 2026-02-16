import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';

const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;
const alice = accounts.get('wallet_1')!;
const bob = accounts.get('wallet_2')!;

describe('BitStack Token', () => {
  describe('Token Metadata', () => {
    it('returns correct name', () => {
      const { result } = simnet.callReadOnlyFn('bitstack-token', 'get-name', [], deployer);
      expect(result).toBeOk(Cl.stringAscii('BitStack Token'));
    });

    it('returns correct symbol', () => {
      const { result } = simnet.callReadOnlyFn('bitstack-token', 'get-symbol', [], deployer);
      expect(result).toBeOk(Cl.stringAscii('BST'));
    });

    it('returns correct decimals', () => {
      const { result } = simnet.callReadOnlyFn('bitstack-token', 'get-decimals', [], deployer);
      expect(result).toBeOk(Cl.uint(6));
    });
  });

  describe('Token Supply', () => {
    it('has correct total supply', () => {
      const { result } = simnet.callReadOnlyFn('bitstack-token', 'get-total-supply', [], deployer);
      expect(result).toBeOk(Cl.uint(100000000000000));
    });

    it('mints initial supply to deployer', () => {
      const { result } = simnet.callReadOnlyFn('bitstack-token', 'get-balance', [Cl.principal(deployer)], deployer);
      expect(result).toBeOk(Cl.uint(100000000000000));
    });
  });

  describe('Token Transfer', () => {
    it('transfers tokens successfully', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'transfer', 
        [Cl.uint(1000), Cl.principal(deployer), Cl.principal(alice), Cl.none()], deployer);
      expect(result).toBeOk(Cl.bool(true));

      const balance = simnet.callReadOnlyFn('bitstack-token', 'get-balance', [Cl.principal(alice)], deployer);
      expect(balance.result).toBeOk(Cl.uint(1000));
    });

    it('fails when sender is not tx-sender', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'transfer',
        [Cl.uint(1000), Cl.principal(deployer), Cl.principal(bob), Cl.none()], alice);
      expect(result).toBeErr(Cl.uint(100));
    });

    it('fails with zero amount', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'transfer',
        [Cl.uint(0), Cl.principal(deployer), Cl.principal(alice), Cl.none()], deployer);
      expect(result).toBeErr(Cl.uint(102));
    });

    it('fails with insufficient balance', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'transfer',
        [Cl.uint(999999999999999), Cl.principal(alice), Cl.principal(bob), Cl.none()], alice);
      expect(result).toBeErr(Cl.uint(1));
    });
  });

  describe('Mint', () => {
    it('mints tokens to recipient', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'mint',
        [Cl.uint(5000), Cl.principal(alice)], deployer);
      expect(result).toBeOk(Cl.bool(true));

      const balance = simnet.callReadOnlyFn('bitstack-token', 'get-balance', [Cl.principal(alice)], deployer);
      expect(balance.result).toBeOk(Cl.uint(5000));
    });

    it('fails with zero amount', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'mint',
        [Cl.uint(0), Cl.principal(alice)], deployer);
      expect(result).toBeErr(Cl.uint(102));
    });
  });

  describe('Burn', () => {
    it('burns tokens from sender', () => {
      simnet.callPublicFn('bitstack-token', 'transfer',
        [Cl.uint(10000), Cl.principal(deployer), Cl.principal(alice), Cl.none()], deployer);

      const { result } = simnet.callPublicFn('bitstack-token', 'burn',
        [Cl.uint(3000), Cl.principal(alice)], alice);
      expect(result).toBeOk(Cl.bool(true));

      const balance = simnet.callReadOnlyFn('bitstack-token', 'get-balance', [Cl.principal(alice)], deployer);
      expect(balance.result).toBeOk(Cl.uint(7000));
    });

    it('fails when sender is not tx-sender', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'burn',
        [Cl.uint(1000), Cl.principal(deployer)], alice);
      expect(result).toBeErr(Cl.uint(100));
    });

    it('fails with zero amount', () => {
      const { result } = simnet.callPublicFn('bitstack-token', 'burn',
        [Cl.uint(0), Cl.principal(alice)], alice);
      expect(result).toBeErr(Cl.uint(102));
    });
  });

  describe('Token URI', () => {
    it('sets and gets token URI', () => {
      const uri = 'https://bitstack.io/token-metadata.json';
      const { result } = simnet.callPublicFn('bitstack-token', 'set-token-uri',
        [Cl.stringUtf8(uri)], deployer);
      expect(result).toBeOk(Cl.bool(true));

      const getUri = simnet.callReadOnlyFn('bitstack-token', 'get-token-uri', [], deployer);
      expect(getUri.result).toBeOk(Cl.some(Cl.stringUtf8(uri)));
    });

    it('returns none initially', () => {
      const { result } = simnet.callReadOnlyFn('bitstack-token', 'get-token-uri', [], deployer);
      expect(result).toBeOk(Cl.none());
    });
  });
});
