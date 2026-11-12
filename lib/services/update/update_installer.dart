import 'dart:io';

import 'package:flutter/services.dart';

import 'package:free_send/core/platform_env.dart';
import 'package:free_send/services/update/update_apply.dart';

/// How an update is handed to the operating system.
enum InstallMethod {
  /// Android: fire the package-installer intent, then the app exits.
  androidPackageInstaller,

  /// Desktop builds replace the app bundle themselves and relaunch.
  replaceAndRelaunch,

  /// This platform cannot self-update yet.
  unsupported,
}

/// Hands a downloaded update to the OS installer and leaves the app.
///
/// The actual work lives behind a method channel so each platform can use its
/// native installer UI; this class only decides which path to take and owns
/// the channel name.
class UpdateInstaller {
  UpdateInstaller({this.channel = _defaultChannel, UpdateApply? apply})
      : _apply = apply ?? const UpdateApply();

  final UpdateApply _apply;

  static const _defaultChannel =
      MethodChannel('com.freesend.free_send/updates');

  final MethodChannel channel;

  InstallMethod get method => switch (PlatformEnv.kind) {
        PlatformKind.android => InstallMethod.androidPackageInstaller,
        PlatformKind.ios => InstallMethod.unsupported,
        PlatformKind.linux => InstallMethod.replaceAndRelaunch,
        PlatformKind.windows => InstallMethod.replaceAndRelaunch,
        PlatformKind.macOS => InstallMethod.replaceAndRelaunch,
        PlatformKind.other => InstallMethod.unsupported,
      };

  bool get isSupported => method != InstallMethod.unsupported;

  /// The architecture identifier release assets are named with: the Android
  /// ABI (`arm64-v8a`) on Android, the architecture word (`x86_64`, `aarch64`)
  /// on Linux. Null on platforms that ship a single build.
  Future<String?> currentArch() async {
    if (method == InstallMethod.androidPackageInstaller) {
      try {
        return await channel.invokeMethod<String>('getAbi');
      } on MissingPluginException {
        return null;
      } on PlatformException {
        return null;
      }
    }
    return PlatformEnv.assetArch;
  }

  /// Opens the native installer for [file]. On Android this shows the system
  /// "Do you want to install this app?" dialog.
  Future<void> install(File file, {String? version}) async {
    switch (method) {
      case InstallMethod.androidPackageInstaller:
        await channel.invokeMethod<void>('installApk', {
          'path': file.path,
          'version': version,
        });
      case InstallMethod.replaceAndRelaunch:
        try {
          await channel.invokeMethod<void>('installPackage', {
            'path': file.path,
            'version': version,
          });
        } on MissingPluginException {
          // Desktop runners have no native updater channel. Apply the package
          // the pipeline published (AppImage, deb, rpm, bundle, or Windows zip).
          await _apply.apply(file);
        }
      case InstallMethod.unsupported:
        throw UnsupportedError(
          'Automatic updates are not available on ${PlatformEnv.label}.',
        );
    }
  }
}
