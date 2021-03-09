import 'dart:math';

import 'package:firebase_dart/src/auth/error.dart';
import 'package:jose/jose.dart';
import 'package:meta/meta.dart';

import 'backend.dart';

class MemoryBackend extends BaseBackend {
  MemoryBackend(
      {@required JsonWebKey tokenSigningKey, @required String projectId})
      : super(tokenSigningKey: tokenSigningKey, projectId: projectId);

  final Map<String, BackendUser> _users = {};

  @override
  Future<BackendUser> getUserById(String uid) async => _users[uid];

  @override
  Future<BackendUser> storeUser(BackendUser user) async =>
      _users[user.localId] = user;

  @override
  Future<BackendUser> getUserByEmail(String email) async {
    return _users.values
        .firstWhere((user) => user.email == email, orElse: () => null);
  }

  @override
  Future<BackendUser> getUserByPhoneNumber(String phoneNumber) async {
    return _users.values.firstWhere((user) => user.phoneNumber == phoneNumber,
        orElse: () => null);
  }

  @override
  Future<void> deleteUser(String uid) async {
    assert(uid != null);
    _users.remove(uid);
  }

  final Map<String, Future<String>> _smsCodes = {};

  Future<String> receiveSmsCode(String phoneNumber) => _smsCodes[phoneNumber];

  @override
  Future<String> sendVerificationCode(String phoneNumber) async {
    var user = await getUserByPhoneNumber(phoneNumber);
    if (user == null) {
      throw FirebaseAuthException.userDeleted();
    }

    var max = 100000;
    var code = (Random.secure().nextInt(max) + max).toString().substring(1);
    _smsCodes[phoneNumber] = Future.value(code);
    var builder = JsonWebSignatureBuilder()
      ..jsonContent = user.phoneNumber
      ..addRecipient(tokenSigningKey);
    return builder.build().toCompactSerialization();
  }

  @override
  Future<BackendUser> verifyPhoneNumber(String sessionInfo, String code) async {
    var s = JsonWebSignature.fromCompactSerialization(sessionInfo);

    var phoneNumber = s.unverifiedPayload.jsonContent;

    var v = await _smsCodes.remove(phoneNumber);
    if (v != code) {
      throw FirebaseAuthException.invalidCode();
    }
    return getUserByPhoneNumber(phoneNumber);
  }
}
