import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Zugangsdaten zur HTW LSF – verschlüsselt im OS-Schlüsselspeicher.
///
/// * Android: EncryptedSharedPreferences / Keystore
/// * iOS & macOS: Keychain
/// * Windows: DPAPI (Credential Locker)
/// * Linux: libsecret (Secret Service / GNOME Keyring)
///
/// Die Daten verlassen das Gerät NIE – es gibt keinen Server (Client-only).
class Credentials {
  const Credentials(this.username, this.password);
  final String username;
  final String password;
}

class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _kUser = 'lsf_username';
  static const _kPass = 'lsf_password';

  Future<void> save(Credentials c) async {
    await _storage.write(key: _kUser, value: c.username);
    await _storage.write(key: _kPass, value: c.password);
  }

  Future<Credentials?> read() async {
    final user = await _storage.read(key: _kUser);
    final pass = await _storage.read(key: _kPass);
    if (user == null || pass == null) return null;
    return Credentials(user, pass);
  }

  Future<bool> hasCredentials() async => (await read()) != null;

  Future<void> clear() async {
    await _storage.delete(key: _kUser);
    await _storage.delete(key: _kPass);
  }
}
