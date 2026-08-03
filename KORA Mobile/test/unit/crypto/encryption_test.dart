import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kora/core/crypto/encryption.dart';

void main() {
  group('EncryptionService', () {
    group('encrypt/decrypt', () {
      test('should encrypt and decrypt text correctly', () {
        const plainText = 'my secret seed phrase';
        const password = 'strong_password_123';
        
        final encrypted = EncryptionService.encrypt(plainText, password);
        final decrypted = EncryptionService.decrypt(encrypted, password);
        
        expect(decrypted, equals(plainText));
      });

      test('should produce different ciphertexts for same input', () {
        const plainText = 'my secret seed phrase';
        const password = 'strong_password_123';
        
        final encrypted1 = EncryptionService.encrypt(plainText, password);
        final encrypted2 = EncryptionService.encrypt(plainText, password);
        
        // Different IVs should produce different ciphertexts
        expect(encrypted1, isNot(equals(encrypted2)));
        
        // But both should decrypt to same plaintext
        expect(EncryptionService.decrypt(encrypted1, password), equals(plainText));
        expect(EncryptionService.decrypt(encrypted2, password), equals(plainText));
      });

      test('should handle unicode text', () {
        const plainText = 'Привіт світ! 🌍 你好世界';
        const password = 'пароль_123';
        
        final encrypted = EncryptionService.encrypt(plainText, password);
        final decrypted = EncryptionService.decrypt(encrypted, password);
        
        expect(decrypted, equals(plainText));
      });

      test('should throw exception on wrong password', () {
        const plainText = 'my secret seed phrase';
        const password = 'correct_password';
        const wrongPassword = 'wrong_password';
        
        final encrypted = EncryptionService.encrypt(plainText, password);
        
        expect(
          () => EncryptionService.decrypt(encrypted, wrongPassword),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should throw exception on invalid encrypted format', () {
        expect(
          () => EncryptionService.decrypt('invalid_format', 'password'),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('should handle empty string', () {
        const plainText = '';
        const password = 'password';
        
        final encrypted = EncryptionService.encrypt(plainText, password);
        final decrypted = EncryptionService.decrypt(encrypted, password);
        
        expect(decrypted, equals(plainText));
      });

      test('should handle long text', () {
        final plainText = 'A' * 10000;
        const password = 'password';
        
        final encrypted = EncryptionService.encrypt(plainText, password);
        final decrypted = EncryptionService.decrypt(encrypted, password);
        
        expect(decrypted, equals(plainText));
      });
    });

    group('encryptBytes/decryptBytes', () {
      test('should encrypt and decrypt bytes correctly', () {
        final data = List<int>.generate(32, (i) => i).toList();
        const password = 'password';
        
        final encrypted = EncryptionService.encryptBytes(
          Uint8List.fromList(data), 
          password,
        );
        final decrypted = EncryptionService.decryptBytes(encrypted, password);
        
        expect(decrypted.toList(), equals(data));
      });
    });

    group('hashPassword/verifyPassword', () {
      test('should hash password and verify correctly', () {
        const password = 'my_secure_password';
        
        final hashed = EncryptionService.hashPassword(password);
        final isValid = EncryptionService.verifyPassword(password, hashed);
        
        expect(isValid, isTrue);
      });

      test('should return different hashes for same password (different salt)', () {
        const password = 'my_secure_password';
        
        final hashed1 = EncryptionService.hashPassword(password);
        final hashed2 = EncryptionService.hashPassword(password);
        
        expect(hashed1, isNot(equals(hashed2)));
        
        // But both should verify
        expect(EncryptionService.verifyPassword(password, hashed1), isTrue);
        expect(EncryptionService.verifyPassword(password, hashed2), isTrue);
      });

      test('should return false for wrong password', () {
        const password = 'correct_password';
        const wrongPassword = 'wrong_password';
        
        final hashed = EncryptionService.hashPassword(password);
        final isValid = EncryptionService.verifyPassword(wrongPassword, hashed);
        
        expect(isValid, isFalse);
      });

      test('should return false for invalid hash format', () {
        const password = 'password';
        const invalidHash = 'invalid_hash';
        
        final isValid = EncryptionService.verifyPassword(password, invalidHash);
        
        expect(isValid, isFalse);
      });
    });

    group('generateRandomKey', () {
      test('should generate different keys each time', () {
        final key1 = EncryptionService.generateRandomKey();
        final key2 = EncryptionService.generateRandomKey();
        
        expect(key1, isNot(equals(key2)));
        expect(key1.length, greaterThan(0));
        expect(key2.length, greaterThan(0));
      });
    });
  });
}
