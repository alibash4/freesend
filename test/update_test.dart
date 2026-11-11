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
                      'name': 'Free Send for Android',
                      'direct_asset_url': 'https://gitlab.com/a/freesend.apk',
                      'size': 1024,
                    },
                    {
                      'name': 'Free Send for Linux',
                      'direct_asset_url':
                          'https://gitlab.com/a/freesend.AppImage',
                      'size': 2048,
                    },
                    {
                      'name': 'Free Send for Windows',
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
                      'name': 'Free Send for Windows',
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
                      'name': 'Free Send for Linux',
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
                      'name': 'Free Send for Linux',
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

  group('UpdateService asset selection by ABI', () {
    final release = {
      'tag_name': 'v1.2.0',
      'description': 'Notes.',
      'assets': {
        'links': [
          {
            'name': 'Free Send for Android (32-bit)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-32.apk',
            'size': 22,
          },
          {
            'name': 'Free Send for Android (64-bit)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-64.apk',
            'size': 26,
          },
          {
            'name': 'Free Send for Android',
            'direct_asset_url': 'https://gitlab.com/a/freesend-universal.apk',
            'size': 69,
          },
          {
            // Another platform's asset must never be considered.
            'name': 'Free Send for Linux',
            'direct_asset_url': 'https://gitlab.com/a/freesend.AppImage',
          },
        ],
      },
    };

    Future<UpdateInfo?> fetchWith(String? abi) async {
      final service = UpdateService(
        // Android asset names, so the test does not depend on the host OS.
        platform: PlatformKind.android,
        client: MockClient(
          (_) async => http.Response(jsonEncode([release]), 200),
        ),
      );
      addTearDown(service.dispose);
      return service.fetchLatest(abi: abi);
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
                  'name': 'Free Send for Android',
                  'direct_asset_url': 'https://gitlab.com/a/freesend.apk',
                },
              ],
            },
          },
        ]), 200)),
      );
      addTearDown(service.dispose);

      final info = await service.fetchLatest(abi: 'arm64-v8a');
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
            'name': 'Free Send for Linux (AppImage)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.AppImage',
          },
          {
            'name': 'Free Send for Linux (deb)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.deb',
          },
          {
            'name': 'Free Send for Linux (rpm)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.rpm',
          },
          {
            'name': 'Free Send for Linux (bundle)',
            'direct_asset_url': 'https://gitlab.com/a/freesend.tar.gz',
          },
          {
            'name': 'Free Send for Windows (exe)',
            'direct_asset_url': 'https://gitlab.com/a/freesend-windows.zip',
          },
          {
            'name': 'Free Send for Android (64-bit)',
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
                  'name': 'Free Send for Linux (bundle)',
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
