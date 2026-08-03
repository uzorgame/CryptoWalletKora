import 'package:flutter_test/flutter_test.dart';
import 'package:kora/core/crypto/mnemonic.dart';

void main() {
  group('MnemonicService', () {
    group('generate12Words', () {
      test('should generate 12 words', () {
        final mnemonic = MnemonicService.generate12Words();
        final words = mnemonic.split(' ');
        
        expect(words.length, equals(12));
      });

      test('should generate different mnemonics each time', () {
        final mnemonic1 = MnemonicService.generate12Words();
        final mnemonic2 = MnemonicService.generate12Words();
        
        expect(mnemonic1, isNot(equals(mnemonic2)));
      });

      test('should generate valid mnemonic', () {
        final mnemonic = MnemonicService.generate12Words();
        final isValid = MnemonicService.validate(mnemonic);
        
        expect(isValid, isTrue);
      });
    });

    group('generate24Words', () {
      test('should generate 24 words', () {
        final mnemonic = MnemonicService.generate24Words();
        final words = mnemonic.split(' ');
        
        expect(words.length, equals(24));
      });

      test('should generate valid mnemonic', () {
        final mnemonic = MnemonicService.generate24Words();
        final isValid = MnemonicService.validate(mnemonic);
        
        expect(isValid, isTrue);
      });
    });

    group('generate', () {
      test('should generate correct word counts', () {
        expect(MnemonicService.generate(wordCount: 12).split(' ').length, equals(12));
        expect(MnemonicService.generate(wordCount: 15).split(' ').length, equals(15));
        expect(MnemonicService.generate(wordCount: 18).split(' ').length, equals(18));
        expect(MnemonicService.generate(wordCount: 21).split(' ').length, equals(21));
        expect(MnemonicService.generate(wordCount: 24).split(' ').length, equals(24));
      });

      test('should throw on invalid word count', () {
        expect(
          () => MnemonicService.generate(wordCount: 10),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('validate', () {
      test('should return true for valid 12-word mnemonic', () {
        final mnemonic = MnemonicService.generate12Words();
        
        expect(MnemonicService.validate(mnemonic), isTrue);
      });

      test('should return true for valid 24-word mnemonic', () {
        final mnemonic = MnemonicService.generate24Words();
        
        expect(MnemonicService.validate(mnemonic), isTrue);
      });

      test('should return false for empty mnemonic', () {
        expect(MnemonicService.validate(''), isFalse);
      });

      test('should return false for invalid word count', () {
        final mnemonic = 'word1 word2 word3';
        
        expect(MnemonicService.validate(mnemonic), isFalse);
      });

      test('should return false for invalid words', () {
        final mnemonic = 'invalidword1 invalidword2 invalidword3 invalidword4 invalidword5 invalidword6 invalidword7 invalidword8 invalidword9 invalidword10 invalidword11 invalidword12';
        
        expect(MnemonicService.validate(mnemonic), isFalse);
      });
    });

    group('mnemonicToSeed', () {
      test('should convert mnemonic to seed', () {
        final mnemonic = MnemonicService.generate12Words();
        final seed = MnemonicService.mnemonicToSeed(mnemonic);
        
        expect(seed.length, equals(64)); // 512 bits
      });

      test('should produce different seeds with passphrase', () {
        final mnemonic = MnemonicService.generate12Words();
        
        final seed1 = MnemonicService.mnemonicToSeed(mnemonic);
        final seed2 = MnemonicService.mnemonicToSeed(mnemonic, passphrase: 'password');
        
        expect(seed1, isNot(equals(seed2)));
      });

      test('should produce consistent seed for same mnemonic', () {
        final mnemonic = MnemonicService.generate12Words();
        
        final seed1 = MnemonicService.mnemonicToSeed(mnemonic);
        final seed2 = MnemonicService.mnemonicToSeed(mnemonic);
        
        expect(seed1, equals(seed2));
      });
    });

    group('splitWords/joinWords', () {
      test('should split and join correctly', () {
        final mnemonic = MnemonicService.generate12Words();
        final words = MnemonicService.splitWords(mnemonic);
        final joined = MnemonicService.joinWords(words);
        
        expect(joined, equals(mnemonic));
      });
    });

    group('areEqual', () {
      test('should return true for equal mnemonics', () {
        final mnemonic = MnemonicService.generate12Words();
        
        expect(MnemonicService.areEqual(mnemonic, mnemonic), isTrue);
      });

      test('should return false for different mnemonics', () {
        final mnemonic1 = MnemonicService.generate12Words();
        final mnemonic2 = MnemonicService.generate12Words();
        
        expect(MnemonicService.areEqual(mnemonic1, mnemonic2), isFalse);
      });

      test('should be case insensitive', () {
        final mnemonic = MnemonicService.generate12Words();
        
        expect(MnemonicService.areEqual(mnemonic, mnemonic.toUpperCase()), isTrue);
      });
    });

    group('hasDuplicateWords', () {
      test('should return false for valid mnemonic', () {
        final mnemonic = MnemonicService.generate12Words();
        
        expect(MnemonicService.hasDuplicateWords(mnemonic), isFalse);
      });

      test('should return true for mnemonic with duplicates', () {
        final mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon';
        
        expect(MnemonicService.hasDuplicateWords(mnemonic), isTrue);
      });
    });

    group('getEntropy', () {
      test('should return correct entropy for 12 words', () {
        final mnemonic = MnemonicService.generate12Words();
        
        expect(MnemonicService.getEntropy(mnemonic), equals(128));
      });

      test('should return correct entropy for 24 words', () {
        final mnemonic = MnemonicService.generate24Words();
        
        expect(MnemonicService.getEntropy(mnemonic), equals(256));
      });
    });

    group('generatePassphrase', () {
      test('should generate passphrase of correct length', () {
        final passphrase = MnemonicService.generatePassphrase(length: 16);
        
        expect(passphrase.length, equals(16));
      });

      test('should generate different passphrases', () {
        final passphrase1 = MnemonicService.generatePassphrase();
        final passphrase2 = MnemonicService.generatePassphrase();
        
        expect(passphrase1, isNot(equals(passphrase2)));
      });
    });
  });
}
