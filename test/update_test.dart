import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:free_send/core/platform_env.dart';
import 'package:free_send/services/update/package_format.dart';
import 'package:free_send/services/update/update_info.dart';
import 'package:free_send/services/update/update_service.dart';

void main() {
  group('UpdateInfo.isNewerThan', () {
    test('rejects the same version', () {
      const info = UpdateInfo(
        version: '1.0.0',
        changelog: '',
        publishedAt: null,
        downloadUrl: '',
        fileName: '',
        sizeBytes: 0,
      );
      expect(info.isNewerThan('1.0.0'), isFalse);
    });

    test('rejects an older app version', () {
      const info = UpdateInfo(
        version: '1.0.0',
        changelog: '',
        publishedAt: null,
        downloadUrl: '',
        fileName: '',
        sizeBytes: 0,
      );
      expect(info.isNewerThan('1.2.0'), isFalse);
    });

    test('accepts a newer release, with or without the v prefix', () {
      const info = UpdateInfo(
        version: '1.2.0',
        changelog: '',
        publishedAt: null,
        downloadUrl: '',
        fileName: '',
        sizeBytes: 0,
      );
      expect(info.isNewerThan('1.1.9'), isTrue);
      expect(info.isNewerThan('v1.1.9'), isTrue);
    });

    test('compares numeric segments, not strings', () {
      const info = UpdateInfo(
        version: '1.10.0',
        changelog: '',
        publishedAt: null,
        downloadUrl: '',
        fileName: '',
        sizeBytes: 0,
      );
      expect(info.isNewerThan('1.9.0'), isTrue);
    });
  });

  group('UpdateService.fetchLatest', () {
    test('picks the asset matching this platform', () async {
      final service = UpdateService(
        client: MockClient((_) async => http.Response(
            jsonEncode([
              {
                'tag_name': 'v1.2.0',
                'description': 'Faster handshakes.',
                'released_at': '2026-01-02T03:04:05.000Z',
                'assets': {
                  'links': [
                    {
                      'name': 'FreeSend for Android',
                      'direct_asset_url': 'https://gitlab.com/a/freesend.apk',
                      'size': 1024,
                    },
                    {
                      'name': 'FreeSend for Linux',
                      'direct_asset_url':
                          'https://gitlab.com/a/freesend.AppImage',
                      'size': 2048,
                    },
                    {
                      'name': 'FreeSend for Windows',
                      'direct_asset_url': 'https://gitlab.com/a/freesend.exe',
                      'size': 4096,
                    },
                  ],
                },
              },
            ]),
            200)),
      );
      addTearDown(service.dispose);

      final latest = await service.fetchLatest();
      expect(latest, isNotNull);
      expect(latest!.version, '1.2.0');
      expect(latest.changelog, 'Faster handshakes.');
      expect(latest.publishedAt, isNotNull);
      expect(
        latest.downloadUrl,
        'https://gitlab.com/a/freesend.AppImage',
      );
      expect(latest.fileName, 'freesend.AppImage');
      expect(latest.sizeBytes, 2048);
    });

    test('skips releases with no asset for this platform', () async {
      final service = UpdateService(
        client: MockClient((_) async => http.Response(
            jsonEncode([
              {
                'tag_name': 'v1.2.0',
                'description': '',
                'assets': {
                  'links': [
                    {
                      'name': 'FreeSend for Windows',
                      'direct_asset_url': 'https://gitlab.com/a/freesend.exe',
                    },
                  ],
                },
              },
              {
                'tag_name': 'v1.1.0',
                'description': 'Older.',
                'assets': {
                  'links': [
                    {
                      'name': 'FreeSend for Linux',
                      'direct_asset_url':
                          'https://gitlab.com/a/freesend.AppImage',
                    },
                  ],
                },
              },
            ]),
            200)),
      );
      addTearDown(service.dispose);

      final latest = await service.fetchLatest();
      expect(latest, isNotNull);
      expect(latest!.version, '1.1.0');
    });

    test('returns null when GitLab has no releases', () async {
      final service = UpdateService(
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      addTearDown(service.dispose);
      expect(await service.fetchLatest(), isNull);
    });

    test('throws on a non-200 response', () async {
      final service = UpdateService(
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      addTearDown(service.dispose);
      expect(
        () => service.fetchLatest(),
        throwsA(isA<HttpException>()),
      );
    });
  });

  group('UpdateService.checkForUpdate', () {
    test('returns nothing when already current', () async {
      final service = UpdateService(
        client: MockClient((_) async => http.Response(
            jsonEncode([
              {
                'tag_name': 'v1.0.0',
                'description': '',
                'assets': {
                  'links': [
                    {
                      'name': 'FreeSend for Linux',
                      'direct_asset_url':
                          'https://gitlab.com/a/freesend.AppImage',
                    },
                  ],
                },
              },
            ]),
            200)),
      );
      addTearDown(service.dispose);

      expect(await service.checkForUpdate('1.0.0'), isNull);
    });
  });

  group('UpdateService asset selection by architecture', () {
    final release = {
      'tag_name': 'v1.2.0',
      'description': 'Notes.',
      'assets': {
        'links': [
          {
            'name': 'FreeSend for Android (32-bit)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-32.apk',
            'size': 22,
          },
          {
            'name': 'FreeSend for Android (64-bit)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-64.apk',
            'size': 26,
          },
          {
            'name': 'FreeSend for Android',
            'direct_asset_url': 'https://gitlab.com/a/freesend-universal.apk',
            'size': 69,
          },
          {
            // Another platform's asset must never be considered.
            'name': 'FreeSend for Linux',
            'direct_asset_url': 'https://gitlab.com/a/freesend.AppImage',
          },
        ],
      },
    };

    Future<UpdateInfo?> fetchWith(String? arch) async {
      final service = UpdateService(
        // Android asset names, so the test does not depend on the host OS.
        platform: PlatformKind.android,
        client: MockClient(
          (_) async => http.Response(jsonEncode([release]), 200),
        ),
      );
      addTearDown(service.dispose);
      return service.fetchLatest(arch: arch);
    }

    test('a 64-bit device gets the 64-bit build', () async {
      final info = await fetchWith('arm64-v8a');
      expect(info!.downloadUrl, contains('freesend-64.apk'));
      expect(info.sizeBytes, 26);
    });

    test('a 32-bit device gets the 32-bit build', () async {
      final info = await fetchWith('armeabi-v7a');
      expect(info!.downloadUrl, contains('freesend-32.apk'));
    });

    test('an ABI with no split falls back to the universal build', () async {
      final info = await fetchWith('x86_64');
      expect(info!.downloadUrl, contains('freesend-universal.apk'));
    });

    test('an unknown ABI still gets the universal build', () async {
      final info = await fetchWith(null);
      expect(info!.downloadUrl, contains('freesend-universal.apk'));
    });

    test('a release with only a universal build works', () async {
      final service = UpdateService(
        platform: PlatformKind.android,
        client: MockClient((_) async => http.Response(jsonEncode([
          {
            'tag_name': 'v1.2.0',
            'description': '',
            'assets': {
              'links': [
                {
                  'name': 'FreeSend for Android',
                  'direct_asset_url': 'https://gitlab.com/a/freesend.apk',
                },
              ],
            },
          },
        ]), 200)),
      );
      addTearDown(service.dispose);

      final info = await service.fetchLatest(arch: 'arm64-v8a');
      expect(info, isNotNull);
      expect(info!.downloadUrl, 'https://gitlab.com/a/freesend.apk');
    });
  });

  group('UpdateService linux and windows packages', () {
    final release = {
      'tag_name': 'v1.4.0',
      'description': 'Packages.',
      'assets': {
        'links': [
          {
            'name': 'FreeSend for Linux (AppImage)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.AppImage',
          },
          {
            'name': 'FreeSend for Linux (deb)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.deb',
          },
          {
            'name': 'FreeSend for Linux (rpm)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.rpm',
          },
          {
            'name': 'FreeSend for Linux (bundle)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.tar.gz',
          },
          {
            'name': 'FreeSend for Windows (exe)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-windows.zip',
          },
          {
            'name': 'FreeSend for macOS (dmg)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-macos.dmg',
          },
          {
            'name': 'FreeSend for Android (64-bit)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-64.apk',
          },
        ],
      },
    };

    Future<UpdateInfo?> fetch(PlatformKind platform, PackageFormat format) {
      final service = UpdateService(
        platform: platform,
        packageFormat: format,
        client: MockClient(
          (_) async => http.Response(jsonEncode([release]), 200),
        ),
      );
      addTearDown(service.dispose);
      return service.fetchLatest();
    }

    test('an AppImage install downloads the AppImage', () async {
      final info = await fetch(PlatformKind.linux, PackageFormat.appImage);
      expect(info!.downloadUrl, contains('AppImage'));
    });

    test('a deb install downloads the deb', () async {
      final info = await fetch(PlatformKind.linux, PackageFormat.deb);
      expect(info!.downloadUrl, endsWith('.deb'));
    });

    test('an rpm install downloads the rpm', () async {
      final info = await fetch(PlatformKind.linux, PackageFormat.rpm);
      expect(info!.downloadUrl, endsWith('.rpm'));
    });

    test('a raw bundle downloads the tar.gz', () async {
      final info = await fetch(PlatformKind.linux, PackageFormat.bundle);
      expect(info!.downloadUrl, endsWith('.tar.gz'));
    });

    test('Windows downloads the exe zip', () async {
      final info = await fetch(PlatformKind.windows, PackageFormat.windows);
      expect(info!.downloadUrl, contains('windows.zip'));
    });

    test('a deb install falls back to the bundle when no deb was published',
        () async {
      final service = UpdateService(
        platform: PlatformKind.linux,
        packageFormat: PackageFormat.deb,
        client: MockClient((_) async => http.Response(jsonEncode([
          {
            'tag_name': 'v1.4.0',
            'description': '',
            'assets': {
              'links': [
                {
                  'name': 'FreeSend for Linux (bundle)',
                  'direct_asset_url': 'https://gitlab.com/a/freesend.tar.gz',
                },
              ],
            },
          },
        ]), 200)),
      );
      addTearDown(service.dispose);
      final info = await service.fetchLatest();
      expect(info!.downloadUrl, endsWith('.tar.gz'));
    });

    test('macOS downloads the DMG', () async {
      final info = await fetch(PlatformKind.macOS, PackageFormat.macOS);
      expect(info!.downloadUrl, endsWith('.dmg'));
    });

    test('macOS prefers the DMG when a release carries more than one build',
        () async {
      final service = UpdateService(
        platform: PlatformKind.macOS,
        packageFormat: PackageFormat.macOS,
        client: MockClient((_) async => http.Response(jsonEncode([
          {
            'tag_name': 'v1.4.0',
            'description': '',
            'assets': {
              'links': [
                {
                  'name': 'FreeSend for macOS (zip)',
                  'direct_asset_url': 'https://gitlab.com/a/freesend-macos.zip',
                },
                {
                  'name': 'FreeSend for macOS (dmg)',
                  'direct_asset_url': 'https://gitlab.com/a/freesend-macos.dmg',
                },
              ],
            },
          },
        ]), 200)),
      );
      addTearDown(service.dispose);
      final info = await service.fetchLatest();
      expect(info!.downloadUrl, endsWith('.dmg'));
    });
  });

  group('UpdateService linux architecture', () {
    final release = {
      'tag_name': 'v1.5.0',
      'description': 'Both architectures.',
      'assets': {
        'links': [
          {
            'name': 'FreeSend for Linux x86_64 (AppImage)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-x86_64.AppImage',
          },
          {
            'name': 'FreeSend for Linux aarch64 (AppImage)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-aarch64.AppImage',
          },
          {
            'name': 'FreeSend for Linux x86_64 (deb)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-x86_64.deb',
          },
          {
            'name': 'FreeSend for Linux aarch64 (deb)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-aarch64.deb',
          },
        ],
      },
    };

    Future<UpdateInfo?> fetch(String? arch, PackageFormat format) {
      final service = UpdateService(
        platform: PlatformKind.linux,
        packageFormat: format,
        client: MockClient(
          (_) async => http.Response(jsonEncode([release]), 200),
        ),
      );
      addTearDown(service.dispose);
      return service.fetchLatest(arch: arch);
    }

    test('an arm64 machine downloads the arm64 build', () async {
      final info = await fetch('aarch64', PackageFormat.appImage);
      expect(info!.downloadUrl, contains('aarch64'));
    });

    test('an x86_64 machine downloads the x86_64 build', () async {
      final info = await fetch('x86_64', PackageFormat.appImage);
      expect(info!.downloadUrl, contains('x86_64'));
    });

    test('the architecture does not change the package format', () async {
      final info = await fetch('aarch64', PackageFormat.deb);
      expect(info!.downloadUrl, endsWith('.deb'));
      expect(info.downloadUrl, contains('aarch64'));
    });

    test('the format fallbacks still apply within the architecture', () async {
      final info = await fetch('aarch64', PackageFormat.bundle);
      expect(info!.downloadUrl, endsWith('.AppImage'));
    });

    test('a release published before the split still updates x86_64', () async {
      final service = UpdateService(
        platform: PlatformKind.linux,
        packageFormat: PackageFormat.appImage,
        client: MockClient((_) async => http.Response(jsonEncode([
          {
            'tag_name': 'v1.4.0',
            'description': '',
            'assets': {
              'links': [
                {
                  'name': 'FreeSend for Linux (AppImage)',
                  'direct_asset_url':
                      'https://gitlab.com/a/freesend.AppImage',
                },
              ],
            },
          },
        ]), 200)),
      );
      addTearDown(service.dispose);
      final info = await service.fetchLatest(arch: 'x86_64');
      expect(info!.downloadUrl, endsWith('.AppImage'));
    });

    test('an arm64 machine skips a release without arm64 assets', () async {
      final service = UpdateService(
        platform: PlatformKind.linux,
        packageFormat: PackageFormat.appImage,
        client: MockClient((_) async => http.Response(jsonEncode([
          {
            'tag_name': 'v1.4.0',
            'description': '',
            'assets': {
              'links': [
                {
                  'name': 'FreeSend for Linux x86_64 (AppImage)',
                  'direct_asset_url':
                      'https://gitlab.com/a/freesend-x86_64.AppImage',
                },
              ],
            },
          },
        ]), 200)),
      );
      addTearDown(service.dispose);
      expect(await service.fetchLatest(arch: 'aarch64'), isNull);
    });
  });

  group('package format marker', () {
    test('APPIMAGE wins over a bundle marker', () {
      expect(
        detectPackageFormat(
          environment: {'APPIMAGE': '/tmp/FreeSend.AppImage'},
          markerText: 'bundle',
        ),
        PackageFormat.appImage,
      );
    });

    test('package-kind selects deb and rpm', () {
      expect(
        detectPackageFormat(environment: {}, markerText: 'deb'),
        PackageFormat.deb,
      );
      expect(
        detectPackageFormat(environment: {}, markerText: 'rpm'),
        PackageFormat.rpm,
      );
    });

    test('package-kind selects the disk image', () {
      expect(
        detectPackageFormat(environment: {}, markerText: 'dmg'),
        PackageFormat.macOS,
      );
    });

    test('macOS asset names carry the dmg marker', () {
      expect(formatMarkers(PackageFormat.macOS), contains('(dmg)'));
    });

    test('a downloaded file maps by its extension', () {
      expect(formatForFile('/tmp/FreeSend.dmg'), PackageFormat.macOS);
      expect(formatForFile('/tmp/freesend.tar.gz'), PackageFormat.bundle);
      expect(formatForFile('/tmp/freesend.apk'), isNull);
    });
  });

  group('UpdateService.download', () {
    test('writes the payload and reports progress', () async {
      const payload = 'fake apk bytes';
      final service = UpdateService(
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://gitlab.com/a/freesend.apk');
          return http.Response(payload, 200);
        }),
      );
      addTearDown(service.dispose);

      final dir = await Directory.systemTemp.createTemp('freesend_dl');
      addTearDown(() => dir.delete(recursive: true));
      final destination = '${dir.path}/freesend.apk';

      final seen = <double>[];
      final file = await service.download(
        const UpdateInfo(
          version: '1.2.0',
          changelog: '',
          publishedAt: null,
          downloadUrl: 'https://gitlab.com/a/freesend.apk',
          fileName: 'freesend.apk',
          sizeBytes: payload.length,
        ),
        destination,
        onProgress: seen.add,
      );

      expect(await file.readAsString(), payload);
      expect(await File('$destination.part').exists(), isFalse);
      expect(seen, isNotEmpty);
      expect(seen.last, 1);
    });

    test('cleans up the partial file when the transfer fails', () async {
      final service = UpdateService(
        client: MockClient((_) async => http.Response('nope', 404)),
      );
      addTearDown(service.dispose);

      final dir = await Directory.systemTemp.createTemp('freesend_dl');
      addTearDown(() => dir.delete(recursive: true));
      final destination = '${dir.path}/freesend.apk';

      // expectLater is awaited, so cleanup has run by the assertions below.
      await expectLater(
        service.download(
          const UpdateInfo(
            version: '1.2.0',
            changelog: '',
            publishedAt: null,
            downloadUrl: 'https://gitlab.com/a/freesend.apk',
            fileName: 'freesend.apk',
            sizeBytes: 0,
          ),
          destination,
        ),
        throwsA(isA<HttpException>()),
      );

      expect(await File(destination).exists(), isFalse);
      expect(await File('$destination.part').exists(), isFalse);
    });
  });
}
