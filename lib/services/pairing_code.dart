import 'dart:io';

import 'package:free_send/core/app_constants.dart';

/// A self-contained invitation to a sharing session: which hotspot to join and
/// where the sender is listening. It is rendered as a QR code so the receiving
/// device never has to type an OS-generated hotspot password.
///
/// The payload is a URI, which means the same value can also be copied as text
/// and pasted on devices without a camera:
///
/// ```
/// freesend://pair?v=1&ssid=FreeSend-Pixel&pw=abc123&host=192.168.43.1&port=47811
/// ```
class PairingCode {
  const PairingCode({
    this.ssid,
    this.password,
    this.host,
    this.port = AppConstants.transferPort,
    this.senderName,
    this.senderPlatform,
  });

  /// Hotspot to join, when the sender is actually hosting one.
  final String? ssid;
  final String? password;

  /// Sender's address on the hotspot link, when known.
  final String? host;
  final int port;

  final String? senderName;
  final String? senderPlatform;

  static const scheme = 'freesend';
  static const hostMark = 'pair';
  static const _version = '1';

  /// True when the receiver can join the hotspot itself from this code.
  bool get hasHotspot => ssid != null && ssid!.isNotEmpty;

  /// True when the code points straight at the sender's listener.
  bool get hasAddress => host != null && host!.isNotEmpty;

  /// A code is only useful if it can name a hotspot or an address.
  bool get isUsable => hasHotspot || hasAddress;

  String encode() {
    final query = <String, String>{
      'v': _version,
      if (hasHotspot) 'ssid': ssid!,
      if (password != null && password!.isNotEmpty) 'pw': password!,
      if (hasAddress) 'host': host!,
      'port': '$port',
      if (senderName != null && senderName!.isNotEmpty) 'name': senderName!,
      if (senderPlatform != null && senderPlatform!.isNotEmpty)
        'pf': senderPlatform!,
    };
    return Uri(
      scheme: scheme,
      host: hostMark,
      queryParameters: query,
    ).toString();
  }

  /// Returns null for anything that is not a Free Send pairing payload, so a QR
  /// code belonging to some other app is ignored instead of half-applied.
  static PairingCode? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final Uri uri;
    try {
      uri = Uri.parse(text);
    } on FormatException {
      return null;
    }
    if (uri.scheme != scheme) return null;
    final query = uri.queryParameters;

    // Version is forward compatible: unknown versions are refused rather than
    // guessed at, because the payload may mean something else entirely.
    final version = query['v'] ?? _version;
    if (version != _version) return null;

    final ssid = _clean(query['ssid']);
    final host = _clean(query['host']);
    final port = int.tryParse(query['port'] ?? '') ?? AppConstants.transferPort;
    if (port < 1 || port > 65535) return null;

    final code = PairingCode(
      ssid: ssid,
      password: _clean(query['pw']),
      // Only accept a real IP literal: the receiver connects to it directly and
      // a hostname from a stranger's QR code should not trigger a DNS lookup.
      host: host != null && InternetAddress.tryParse(host) != null ? host : null,
      port: port,
      senderName: _clean(query['name']),
      senderPlatform: _clean(query['pf']),
    );
    return code.isUsable ? code : null;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Short description used in progress and error text.
  String get label =>
      senderName ?? (hasAddress ? '$host:$port' : ssid ?? 'the other device');
}
