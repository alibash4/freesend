import 'dart:convert';

/// A sender whose long-term Ed25519 key has been pinned on this device.
class TrustedDevice {
  const TrustedDevice({
    required this.instanceId,
    required this.name,
    required this.publicKey,
    required this.fingerprint,
    required this.addedAt,
  });

  final String instanceId;
  final String name;
  final String publicKey;
  final String fingerprint;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
        'id': instanceId,
        'name': name,
        'key': publicKey,
        'fingerprint': fingerprint,
        'at': addedAt.millisecondsSinceEpoch,
      };

  static TrustedDevice? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final key = json['key'];
    final fingerprint = json['fingerprint'];
    final at = json['at'];
    if (id is! String || name is! String || key is! String ||
        fingerprint is! String || at is! num) {
      return null;
    }
    return TrustedDevice(
      instanceId: id,
      name: name,
      publicKey: key,
      fingerprint: fingerprint,
      addedAt: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }

  static String encodeKey(List<int> bytes) => base64.encode(bytes);
}