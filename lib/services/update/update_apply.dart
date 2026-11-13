import 'dart:io';

import 'package:free_send/services/update/package_format.dart';

/// Applies a downloaded desktop package and starts the new copy.
///
/// Android keeps using the package-installer method channel. Desktop has no
/// native bridge, so the formats the pipeline publishes are applied here:
///
/// * AppImage — replace the file in `APPIMAGE` and relaunch it.
/// * bundle — extract the tar.gz over the current bundle after this process
///   exits, then relaunch `free_send`.
/// * deb / rpm — hand the package to the system package manager.
/// * Windows — extract the zip (it contains `free_send.exe`) over the install
///   folder after this process exits, then relaunch.
/// * macOS — mount the disk image, swap the `.app` bundle it carries for the
///   running one after this process exits, then relaunch.
class UpdateApply {
  const UpdateApply();

  Future<void> apply(File file) async {
    final format = _formatFor(file);
    switch (format) {
      case PackageFormat.appImage:
        await _replaceAppImage(file);
      case PackageFormat.bundle:
        await _stageSwap(
          archive: file,
          destination: _bundleDir(),
          launch: '${_bundleDir()}${Platform.pathSeparator}free_send',
          extract: 'tar',
        );
      case PackageFormat.deb:
        await _runPrivileged(['dpkg', '-i', file.path]);
      case PackageFormat.rpm:
        await _runPrivileged(['rpm', '-Uvh', file.path]);
      case PackageFormat.windows:
        final dir = File(Platform.resolvedExecutable).parent.path;
        await _stageSwap(
          archive: file,
          destination: dir,
          launch: Platform.resolvedExecutable,
          extract: 'powershell',
        );
      case PackageFormat.macOS:
        await _installDmg(file);
      case PackageFormat.android:
        throw UnsupportedError('Android updates use the package installer.');
    }
  }

  PackageFormat _formatFor(File file) =>
      formatForFile(file.path) ?? detectPackageFormat();

  /// The `.app` bundle that holds the running executable, which lives at
  /// `<bundle>/Contents/MacOS/<executable>`.
  String get _appBundlePath =>
      File(Platform.resolvedExecutable).parent.parent.parent.path;

  /// Installs a disk image: mount it, replace the running `.app` with the one
  /// it carries, then relaunch.
  ///
  /// A running bundle cannot be replaced from underneath itself, so — like the
  /// bundle and Windows zip paths — the work is handed to a detached script
  /// that waits for this process to exit first.
  Future<void> _installDmg(File file) async {
    final bundle = _appBundlePath;
    final script = await _writeScript('''
#!/bin/sh
while kill -0 $pid 2>/dev/null; do sleep 0.2; done
mountpoint="\$(mktemp -d)"
if ! hdiutil attach "${file.path}" -nobrowse -readonly -mountpoint "\$mountpoint" >/dev/null 2>&1; then
  rmdir "\$mountpoint"
  exit 1
fi
app="\$(ls -d "\$mountpoint"/*.app 2>/dev/null | head -1)"
if [ -z "\$app" ]; then
  hdiutil detach "\$mountpoint" -force
  rmdir "\$mountpoint"
  exit 1
fi
rm -rf "$bundle"
cp -R "\$app" "$bundle"
# A freshly downloaded bundle is quarantined, which would stop the updated
# copy from opening. This is the app's own build, so clear the flag.
xattr -dr com.apple.quarantine "$bundle" 2>/dev/null
hdiutil detach "\$mountpoint" -force
rm -rf "\$mountpoint"
open -n "$bundle"
''');
    await Process.start(script, [], mode: ProcessStartMode.detached);
  }

  Future<void> _replaceAppImage(File file) async {
    final target = Platform.environment['APPIMAGE'];
    if (target == null || target.isEmpty) {
      throw StateError(
        'This is not an AppImage launch, so the AppImage cannot be replaced.',
      );
    }
    final staged = File('$target.new');
    await file.copy(staged.path);
    await Process.run('chmod', ['755', staged.path]);
    final script = await _writeScript('''
#!/bin/sh
while kill -0 $pid 2>/dev/null; do sleep 0.2; done
mv -f \"$target.new\" \"$target\"
chmod 755 \"$target\"
exec \"$target\"
''');
    await Process.start(script, [], mode: ProcessStartMode.detached);
  }

  Future<void> _stageSwap({
    required File archive,
    required String destination,
    required String launch,
    required String extract,
  }) async {
    final script = extract == 'powershell'
        ? await _writeScript(_windowsScript(archive, destination, launch), ext: 'ps1')
        : await _writeScript(_linuxScript(archive, destination, launch));
    if (extract == 'powershell') {
      await Process.start(
        'powershell',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script],
        mode: ProcessStartMode.detached,
      );
    } else {
      await Process.start(script, [], mode: ProcessStartMode.detached);
    }
  }

  String _linuxScript(File archive, String destination, String launch) => '''
#!/bin/sh
while kill -0 $pid 2>/dev/null; do sleep 0.2; done
rm -rf \"$destination\"
mkdir -p \"$destination\"
tar -xzf \"${archive.path}\" -C \"$destination\"
chmod 755 \"$launch\"
exec \"$launch\"
''';

  String _windowsScript(File archive, String destination, String launch) => '''
while (Get-Process -Id $pid -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }
Expand-Archive -LiteralPath \"${archive.path}\" -DestinationPath \"$destination\" -Force
Start-Process -FilePath \"$launch\"
''';

  Future<void> _runPrivileged(List<String> args) async {
    final result = await Process.run('pkexec', args);
    if (result.exitCode != 0) {
      final detail = '${result.stderr}'.trim();
      throw ProcessException(
        'pkexec',
        args,
        detail.isEmpty ? 'Package install failed.' : detail,
        result.exitCode,
      );
    }
  }

  String _bundleDir() => File(Platform.resolvedExecutable).parent.path;

  Future<String> _writeScript(String body, {String ext = 'sh'}) async {
    final dir = await Directory.systemTemp.createTemp('freesend_apply');
    final file = File('${dir.path}${Platform.pathSeparator}apply.$ext');
    await file.writeAsString(body);
    if (ext == 'sh') await Process.run('chmod', ['755', file.path]);
    return file.path;
  }
}
