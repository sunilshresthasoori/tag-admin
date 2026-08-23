import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';

class EncryptionHelperRecharge {
  static const String hmacKey = "0WUKZlFdeJQ17fGU62BPudBLNpWY4kxJ9iv7P_fyRBoLBTl-7HktiWWFX12KyKga9AiF7J07bTVBxTuH3t1x7w";
  static const String apiKey = "MXNvb3JpMDE=";
  static const String rsaPublicKey = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2JAljdZzK0aTXC2Au0o2leOKu1gKueeUiCnWaVF0z868sLqR8d4QrxgeuVrtI24hvGOMPTdUuCrzx0W6YGASCHWcydnn75tuMCBz8ynPuh6Nayo7yk7oG52KyLKj1UPbLLgxxvHWkzeYXwTHrxTRoOJo+mm6Yg/sqdPuXEbcj8sAAimC8xDDpJqHGHKQ81RD+fGZPIDe2RaqBAu2Ajg6Ff/mhQOnH1sRc2NEORZiBwihUovO7aW7ucgLrhFBoRSifhWTyrfggqPQBsaRXnqrWMuAFo86n6owbAaY9wwRL9BsD7GV/6EBMMPf3jd4bm7bwt0QIlFpMoN2nk1nBNDLFQIDAQAB";

  static Map<String, dynamic> prepareRechargeRequest({
    required String userName,
    required Map<String, dynamic> payloadData,
  }) {
    try {
      print('\n========== DEBUG: PREPARE RECHARGE REQUEST ==========');
      print('DEBUG: Username: $userName');
      print('DEBUG: API Key: $apiKey');
      print('DEBUG: HMAC Key: $hmacKey');
      
      // Generate UUID and timestamp
      final uuid = const Uuid().v4();
      final currentTime = DateTime.now().toUtc();
      // Use current timestamp (Unix timestamp in seconds)
      final timestamp = currentTime.millisecondsSinceEpoch ~/ 1000;
      
      print('DEBUG: Generated UUID: $uuid');
      print('DEBUG: Timestamp: $timestamp');
      print('DEBUG: Current DateTime: $currentTime');

      // Generate signature
      final signature = _generateSignature(
        userName: userName,
        apiKey: apiKey,
        uuid: uuid,
        timestamp: timestamp,
        hmacKey: hmacKey,
      );
      
      print('DEBUG: Generated Signature: $signature');

      // Generate authorization token
      final authToken = _generateAuthToken(
        userName: userName,
        uuid: uuid,
        signature: signature,
        timestamp: timestamp,
      );
      
      print('DEBUG: Generated Auth Token: $authToken');

      // Generate unique AES secret key
      final aesSecretKey = _generateRandomBytes(32); // 256 bits

      print("DEBUG: Generated AES Key (Base64): ${base64Encode(aesSecretKey)}");

      // Encrypt AES key with RSA
      final encryptedSecretKey = _encryptWithRSA(
        base64Encode(aesSecretKey),
        rsaPublicKey,
      );

      if (encryptedSecretKey == null) {
        throw Exception('Failed to encrypt AES secret key with RSA');
      }

      // Encrypt payload with AES (without IV)
      final encryptedPayload = _encryptPayloadWithAES(
        payloadData,
        aesSecretKey,
      );
      
      print('DEBUG: Encrypted Secret Key: $encryptedSecretKey');
      print('DEBUG: Encrypted Payload: ${encryptedPayload.substring(0, encryptedPayload.length > 100 ? 100 : encryptedPayload.length)}...');
      print('========== END DEBUG: PREPARE RECHARGE REQUEST ==========\n');

      return {
        'authToken': authToken,
        'requestBody': {
          'secretKey': encryptedSecretKey,
          'payload': encryptedPayload,
        },
        'aesKey': aesSecretKey,
      };
    } catch (e) {
      throw Exception('Failed to prepare recharge request: $e');
    }
  }

  static String _generateSignature({
    required String userName,
    required String apiKey,
    required String uuid,
    required int timestamp,
    required String hmacKey,
  }) {
    // Concatenate data: username + apiKey + uuid + timestamp
    final data = userName + apiKey + uuid + timestamp.toString();
    
    print('DEBUG: Signature Input String: $data');
    print('DEBUG: Signature Input Parts: userName=$userName, apiKey=$apiKey, uuid=$uuid, timestamp=$timestamp');

    // Generate HMAC-SHA256
    final key = utf8.encode(hmacKey);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    
    final signature = base64Encode(digest.bytes);
    print('DEBUG: Generated Signature from HMAC: $signature');

    return signature;
  }

  static String _generateAuthToken({
    required String userName,
    required String uuid,
    required String signature,
    required int timestamp,
  }) {
    // Combine: userName:uuid:signature:timestamp
    final tokenData = '$userName:$uuid:$signature:$timestamp';
    
    print('DEBUG: Auth Token Data (before encoding): $tokenData');

    // Base64 encode
    final authToken = base64Encode(utf8.encode(tokenData));
    print('DEBUG: Auth Token (Base64 encoded): $authToken');
    
    return authToken;
  }

  static String _encryptPayloadWithAES(Map<String, dynamic> payload, Uint8List aesKey) {
    try {
      // Convert payload to JSON
      final jsonPayload = jsonEncode(payload);
      final payloadBytes = utf8.encode(jsonPayload);

      // Encrypt with AES-ECB (no IV needed)
      final encryptedBytes = _aesEncrypt(payloadBytes, aesKey);

      // Encode to base64
      return base64Encode(encryptedBytes);
    } catch (e) {
      throw Exception('Failed to encrypt payload: $e');
    }
  }

  static Map<String, dynamic> decryptResponse(String encryptedResponse, Uint8List aesKey) {
    try {
      // Decode from base64
      final encryptedData = base64Decode(encryptedResponse);

      // Decrypt with AES-ECB (no IV needed)
      final decryptedBytes = _aesDecrypt(encryptedData, aesKey);

      // Convert to JSON
      final jsonString = utf8.decode(decryptedBytes);
      return jsonDecode(jsonString);
    } catch (e) {
      throw Exception('Failed to decrypt response: $e');
    }
  }

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (i) => random.nextInt(256)),
    );
  }

  static Uint8List _aesEncrypt(List<int> plaintext, Uint8List key) {
    // Pad the plaintext using PKCS7
    final paddedPlaintext = _pkcs7Pad(plaintext, 16);

    // Initialize AES cipher in ECB mode (no IV)
    final cipher = ECBBlockCipher(AESEngine())
      ..init(true, KeyParameter(key));

    final ciphertext = Uint8List(paddedPlaintext.length);
    var offset = 0;

    while (offset < paddedPlaintext.length) {
      offset += cipher.processBlock(paddedPlaintext, offset, ciphertext, offset);
    }

    return ciphertext;
  }

  static Uint8List _aesDecrypt(Uint8List ciphertext, Uint8List key) {
    // Initialize AES cipher for decryption in ECB mode (no IV)
    final cipher = ECBBlockCipher(AESEngine())
      ..init(false, KeyParameter(key));

    final plaintext = Uint8List(ciphertext.length);
    var offset = 0;

    while (offset < ciphertext.length) {
      offset += cipher.processBlock(ciphertext, offset, plaintext, offset);
    }

    // Remove PKCS7 padding
    return _pkcs7Unpad(plaintext);
  }

  static Uint8List _pkcs7Pad(List<int> data, int blockSize) {
    final padding = blockSize - (data.length % blockSize);
    final paddedData = List<int>.from(data);

    for (int i = 0; i < padding; i++) {
      paddedData.add(padding);
    }

    return Uint8List.fromList(paddedData);
  }

  static Uint8List _pkcs7Unpad(Uint8List data) {
    final paddingLength = data.last;
    return data.sublist(0, data.length - paddingLength);
  }

  static String? _encryptWithRSA(String data, String publicKeyPem) {
    try {
      // Clean the PEM key
      String cleanKey = publicKeyPem
          .replaceAll('-----BEGIN PUBLIC KEY-----', '')
          .replaceAll('-----END PUBLIC KEY-----', '')
          .replaceAll('-----BEGIN RSA PUBLIC KEY-----', '')
          .replaceAll('-----END RSA PUBLIC KEY-----', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .replaceAll(' ', '')
          .trim();

      final keyBytes = base64Decode(cleanKey);

      // Parse the public key
      RSAPublicKey? rsaPublicKey = _parseRSAPublicKey(keyBytes);

      if (rsaPublicKey == null) {
        throw Exception('Failed to parse RSA public key');
      }

      // Use PKCS1 padding first
      try {
        final encrypter = PKCS1Encoding(RSAEngine())
          ..init(true, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));

        final dataBytes = utf8.encode(data);
        final encryptedBytes = encrypter.process(Uint8List.fromList(dataBytes));
        return base64Encode(encryptedBytes);
      } catch (e) {
        // If PKCS1 fails, try OAEP
        final encrypter = OAEPEncoding(RSAEngine())
          ..init(true, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));

        final dataBytes = utf8.encode(data);
        final encryptedBytes = encrypter.process(Uint8List.fromList(dataBytes));
        return base64Encode(encryptedBytes);
      }
    } catch (e) {
      print('RSA encryption error: $e');
      return null;
    }
  }

  static RSAPublicKey? _parseRSAPublicKey(Uint8List keyBytes) {
    try {
      final parser = ASN1Parser(keyBytes);
      final ASN1Object topLevel = parser.nextObject();

      if (topLevel is ASN1Sequence) {
        // Check if it's a PKCS#8 format (SubjectPublicKeyInfo)
        if (topLevel.elements.length == 2) {
          final ASN1BitString publicKeyBits = topLevel.elements[1] as ASN1BitString;

          // Parse the actual RSA public key from the bit string
          final rsaKeyParser = ASN1Parser(publicKeyBits.contentBytes());
          final ASN1Sequence rsaKeySeq = rsaKeyParser.nextObject() as ASN1Sequence;

          final modulus = (rsaKeySeq.elements[0] as ASN1Integer).valueAsBigInteger;
          final exponent = (rsaKeySeq.elements[1] as ASN1Integer).valueAsBigInteger;

          return RSAPublicKey(modulus, exponent);
        } else {
          // Assume it's PKCS#1 format (RSAPublicKey)
          final modulus = (topLevel.elements[0] as ASN1Integer).valueAsBigInteger;
          final exponent = (topLevel.elements[1] as ASN1Integer).valueAsBigInteger;

          return RSAPublicKey(modulus, exponent);
        }
      }
    } catch (e) {
      print('Error parsing RSA public key: $e');
    }

    return null;
  }
}

