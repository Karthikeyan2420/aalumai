import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppPreferences> testAppPreferences({
  bool notificationsEnabled = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'notifications_enabled': notificationsEnabled,
  });
  return AppPreferences(await SharedPreferences.getInstance());
}
