import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> testSharedPreferences({
  bool notificationsEnabled = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'notifications_enabled': notificationsEnabled,
  });
  return SharedPreferences.getInstance();
}

Future<AppPreferences> testAppPreferences({
  bool notificationsEnabled = true,
}) async {
  return AppPreferences(
    await testSharedPreferences(notificationsEnabled: notificationsEnabled),
  );
}
