import 'dart:io';

class AppConstants {
  static const String appName = "Yaltes Car App";
  static const int app_version = 1;

  static String get BASE_URL {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8000";
    } else if (Platform.isIOS) {
      return "http://127.0.0.1:8000";
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return "http://127.0.0.1:8000";
    } else {
      return "http://127.0.0.1:8000";
    }
  }

  static const String kTokenKey = 'jwt_token';
  //default padding yazarım belki?? + default logo
}
