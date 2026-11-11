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
      case PackageFormat.android:
        throw UnsupportedError('Android updates use the package installer.');
    }
  }

  PackageFormat _formatFor(File file) {
    final name = file.path.toLowerCase();
    if (name.endsWith('.appimage')) return PackageFormat.appImage;
    if (name.endsWith('.deb')) return PackageFormat.deb;
    if (name.endsWith('.rpm')) return PackageFormat.rpm;
    if (name.endsWith('.tar.gz') || name.endsWith('.tgz')) {
      return PackageFormat.bundle;
    }
    if (name.endsWith('.zip') || name.endsWith('.exe')) {
      return PackageFormat.windows;
    }
    return detectPackageFormat();
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
mv -f "$target.new" "$target"
chmod 755 "$target"
exec "$target"
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
rm -rf "$destination"
mkdir -p "$destination"
tar -xzf "${archive.path}" -C "$destination"
chmod 755 "$launch"
exec "$launch"
''';

  String _windowsScript(File archive, String destination, String launch) => '''
while (Get-Process -Id $pid -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 200 }
Expand-Archive -LiteralPath "${archive.path}" -DestinationPath "$destination" -Force
Start-Process -FilePath "$launch"
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
