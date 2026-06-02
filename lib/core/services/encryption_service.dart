/*
The Cryptographic Engine (Core Service)
This service will handle the hard math: generating salts, deriving secure cryptographic keys, and packaging/unpacking files

By using AesGcm natively, if someone maliciously modifies a byte of the encrypted file on a USB drive,
the decryptBytes function will immediately fail, protecting the operating system from buffer overflows.

File struct for .crypta files: [Salt (16 bytes)] + [Nonce (12 bytes)] + [Ciphertext (Variable)] + [MAC Tag (16 bytes)]
*/

import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  final _aesGcm = AesGcm.with256bits();
  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );

  /// Encrypts and packages: [Salt (16B)] + [Nonce (12B)] + [CipherText] + [MAC (16B)]
  Future<Uint8List> encryptBytes(
      Uint8List plainBytes, Uint8List passwordBytes) async {
    try {
      // 1. Generate Salt and Nonce
      final salt = SecretKeyData.random(length: 16).bytes;
      final nonce = _aesGcm.newNonce();

      // 2. Derive the AES-256 key
      final secretKey = await _pbkdf2.deriveKeyFromPassword(
        password: String.fromCharCodes(
            passwordBytes), // Minimize the String's lifetime to prevent brute-force attacks
        nonce: salt,
      );

      // 3. Encrypt using AES-GCM
      final secretBox = await _aesGcm.encrypt(
        plainBytes,
        secretKey: secretKey,
        nonce: nonce,
      );

      // 4. Build the binary package (including MAC)
      final builder = BytesBuilder();
      builder.add(salt); // 16 bytes
      builder.add(secretBox.nonce); // 12 bytes
      builder.add(secretBox.cipherText); // Variable data length
      builder.add(secretBox.mac.bytes); // 16 bytes

      return builder.takeBytes();
    } finally {
      // Overwrote the data in RAM with zeros so that no one can read it from the heap
      plainBytes.fillRange(0, plainBytes.length, 0);
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }

  /// Unpack and decrypt, validating authenticity
  Future<Uint8List> decryptBytes(
      Uint8List encryptedBytes, Uint8List passwordBytes) async {
    try {
      // 16(Salt) + 12(Nonce) + 1(Min Cipher) + 16(MAC) = Min 45 bytes
      if (encryptedBytes.length < 44) {
        throw const FormatException('The file is incomplete or corrupt.');
      }

      // 1. Extract the components by calculating from the beginning and the end
      final salt = encryptedBytes.sublist(0, 16);
      final nonce = encryptedBytes.sublist(16, 28);

      // The MAC address is always the last 16 bytes of the file.
      final macBytes = encryptedBytes.sublist(encryptedBytes.length - 16);

      // The ciphertext is everything between the Nonce and the MAC
      final cipherText = encryptedBytes.sublist(28, encryptedBytes.length - 16);

      // 2. Rebuild the key
      final secretKey = await _pbkdf2.deriveKeyFromPassword(
        password: String.fromCharCodes(passwordBytes),
        nonce: salt,
      );

      // 3. Assemble the secret box with its real MAC
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      // 4. Decrypt (If the password is bad or a byte has changed, it will fail here)
      final clearBytes = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      return Uint8List.fromList(clearBytes);
    } finally {
      passwordBytes.fillRange(0, passwordBytes.length, 0);
    }
  }
}
