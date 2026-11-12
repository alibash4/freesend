import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:free_send/services/local_store.dart';
import 'package:free_send/services/permissions/app_permissions.dart';

void main() {
  test('desktop builds do not need runtime permissions', () {
    expect(AppPermissions.isMobile, isFalse);
    expect(AppPermissions.required, isEmpty);
    expect(AppPermissions.localNetworkNote, isEmpty);
  });

  test('the permission prompt flag persists', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.init();
    expect(store.permissionsPrompted, isFalse);
    await store.setPermissionsPrompted(true);
    expect(store.permissionsPrompted, isTrue);
  });
}