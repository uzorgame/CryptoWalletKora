import 'package:flutter_test/flutter_test.dart';
import 'package:kora/core/crypto/key_manager.dart';
import 'package:kora/core/crypto/mnemonic.dart';

void main() {
  group('KeyManager', () {
    const testPin = '123456';
    
    // Очищаємо перед кожним тестом
    setUp(() async {
      await KeyManager.deleteAll();
    });

    // Очищаємо після всіх тестів
    tearDownAll(() async {
      await KeyManager.deleteAll();
    });

    group('Seed Phrase', () {
      const testWalletId = 'wallet_test_001';

      test('should store and retrieve seed phrase', () async {
        final mnemonic = MnemonicService.generate12Words();

        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);
        final retrieved = await KeyManager.getSeedPhrase(testPin, walletId: testWalletId);

        expect(retrieved, equals(mnemonic));
      });

      test('should return null for non-existent seed phrase', () async {
        final retrieved = await KeyManager.getSeedPhrase(testPin, walletId: testWalletId);

        expect(retrieved, isNull);
      });

      test('should return null with wrong PIN', () async {
        final mnemonic = MnemonicService.generate12Words();
        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);

        final retrieved = await KeyManager.getSeedPhrase('wrong_pin', walletId: testWalletId);

        expect(retrieved, isNull);
      });

      test('should check if seed phrase exists', () async {
        expect(await KeyManager.hasSeedPhrase(walletId: testWalletId), isFalse);

        final mnemonic = MnemonicService.generate12Words();
        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);

        expect(await KeyManager.hasSeedPhrase(walletId: testWalletId), isTrue);
      });

      test('should delete seed phrase', () async {
        final mnemonic = MnemonicService.generate12Words();
        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);
        await KeyManager.deleteSeedPhrase(walletId: testWalletId);

        expect(await KeyManager.hasSeedPhrase(walletId: testWalletId), isFalse);
        expect(await KeyManager.getSeedPhrase(testPin, walletId: testWalletId), isNull);
      });

      test('should update seed phrase', () async {
        final mnemonic1 = MnemonicService.generate12Words();
        final mnemonic2 = MnemonicService.generate12Words();

        await KeyManager.storeSeedPhrase(mnemonic1, testPin, walletId: testWalletId);
        await KeyManager.storeSeedPhrase(mnemonic2, testPin, walletId: testWalletId);

        final retrieved = await KeyManager.getSeedPhrase(testPin, walletId: testWalletId);
        expect(retrieved, equals(mnemonic2));
      });
    });

    group('Private Keys', () {
      test('should store and retrieve private key', () async {
        const blockchain = 'ethereum';
        const address = '0x1234567890abcdef';
        const privateKey = 'private_key_hex';
        
        await KeyManager.storePrivateKey(
          blockchain: blockchain,
          address: address,
          privateKey: privateKey,
          pin: testPin,
        );
        
        final retrieved = await KeyManager.getPrivateKey(
          blockchain: blockchain,
          address: address,
          pin: testPin,
        );
        
        expect(retrieved, equals(privateKey));
      });

      test('should store multiple private keys', () async {
        await KeyManager.storePrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          privateKey: 'eth_key',
          pin: testPin,
        );
        await KeyManager.storePrivateKey(
          blockchain: 'bitcoin',
          address: 'bc1q123',
          privateKey: 'btc_key',
          pin: testPin,
        );
        
        final ethKey = await KeyManager.getPrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          pin: testPin,
        );
        final btcKey = await KeyManager.getPrivateKey(
          blockchain: 'bitcoin',
          address: 'bc1q123',
          pin: testPin,
        );
        
        expect(ethKey, equals('eth_key'));
        expect(btcKey, equals('btc_key'));
      });

      test('should return null for non-existent key', () async {
        final retrieved = await KeyManager.getPrivateKey(
          blockchain: 'ethereum',
          address: '0x999',
          pin: testPin,
        );
        
        expect(retrieved, isNull);
      });

      test('should delete private key', () async {
        await KeyManager.storePrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          privateKey: 'eth_key',
          pin: testPin,
        );
        
        await KeyManager.deletePrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          pin: testPin,
        );
        
        final retrieved = await KeyManager.getPrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          pin: testPin,
        );
        
        expect(retrieved, isNull);
      });

      test('should delete all private keys', () async {
        await KeyManager.storePrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          privateKey: 'eth_key',
          pin: testPin,
        );
        await KeyManager.storePrivateKey(
          blockchain: 'bitcoin',
          address: 'bc1q123',
          privateKey: 'btc_key',
          pin: testPin,
        );
        
        await KeyManager.deleteAllPrivateKeys();
        
        final ethKey = await KeyManager.getPrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          pin: testPin,
        );
        
        expect(ethKey, isNull);
      });
    });

    group('Wallet Addresses', () {
      test('should store and retrieve wallet addresses', () async {
        final addresses = [
          {'blockchain': 'ethereum', 'address': '0x123'},
          {'blockchain': 'bitcoin', 'address': 'bc1q123'},
        ];
        
        await KeyManager.storeWalletAddresses(addresses);
        final retrieved = await KeyManager.getWalletAddresses();
        
        expect(retrieved.length, equals(2));
        expect(retrieved[0]['blockchain'], equals('ethereum'));
      });

      test('should return empty list when no addresses', () async {
        final retrieved = await KeyManager.getWalletAddresses();
        
        expect(retrieved, isEmpty);
      });
    });

    group('Backup Status', () {
      test('should mark backup as done', () async {
        expect(await KeyManager.isBackupDone(), isFalse);
        
        await KeyManager.markBackupAsDone();
        
        expect(await KeyManager.isBackupDone(), isTrue);
      });

      test('should track last backup date', () async {
        await KeyManager.markBackupAsDone();
        
        final lastBackup = await KeyManager.getLastBackupDate();
        
        expect(lastBackup, isNotNull);
        expect(lastBackup!.isBefore(DateTime.now()), isTrue);
      });
    });

    group('General', () {
      const testWalletId = 'wallet_test_001';

      test('should delete all data', () async {
        final mnemonic = MnemonicService.generate12Words();
        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);
        await KeyManager.storePrivateKey(
          blockchain: 'ethereum',
          address: '0x123',
          privateKey: 'key',
          pin: testPin,
        );

        await KeyManager.deleteAll();

        expect(await KeyManager.hasSeedPhrase(walletId: testWalletId), isFalse);
        expect(await KeyManager.hasAnyData(), isFalse);
      });

      test('should check if any data exists', () async {
        expect(await KeyManager.hasAnyData(), isFalse);

        final mnemonic = MnemonicService.generate12Words();
        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);

        expect(await KeyManager.hasAnyData(), isTrue);
      });
    });

    group('Change PIN', () {
      const testWalletId = 'wallet_test_001';
      const newPin = '654321';

      test('should change PIN successfully', () async {
        final mnemonic = MnemonicService.generate12Words();
        await KeyManager.storeAppPin(testPin);
        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);

        final result = await KeyManager.changePin(
            testPin, newPin, walletIds: [testWalletId]);

        expect(result, isTrue);
        expect(await KeyManager.getSeedPhrase(newPin, walletId: testWalletId),
            equals(mnemonic));
        expect(await KeyManager.getSeedPhrase(testPin, walletId: testWalletId),
            isNull);
      });

      test('should fail to change PIN with wrong old PIN', () async {
        final mnemonic = MnemonicService.generate12Words();
        await KeyManager.storeAppPin(testPin);
        await KeyManager.storeSeedPhrase(mnemonic, testPin, walletId: testWalletId);

        final result = await KeyManager.changePin(
            'wrong_pin', newPin, walletIds: [testWalletId]);

        expect(result, isFalse);
        expect(await KeyManager.getSeedPhrase(testPin, walletId: testWalletId),
            equals(mnemonic));
      });
    });
  });
}
