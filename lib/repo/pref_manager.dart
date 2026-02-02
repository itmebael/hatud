import 'package:shared_preferences/shared_preferences.dart';

class PrefManager {
  static late final SharedPreferences _appPref;
  static const KEY_IS_LOGIN = "is_login";
  static const KEY_DEFAULT_LAN = "default_lan";
  static const KEY_DEFAULT_LAN_CODE = "default_lan_code";
  static const KEY_ONCE_PROMPT_TO_ADD_LOCATION = "once_prompt_to_add_location";
  static const KEY_IS_LOCATION_SEL_FINISH = "is_location_sel_finish";
  static const KEY_USER_EMAIL = "user_email";
  static const KEY_USER_NAME = "user_name";
  static const KEY_USER_ROLE = "user_role";
  static const KEY_USER_PHONE = "user_phone";
  static const KEY_USER_ADDRESS = "user_address";
  static const KEY_USER_IMAGE = "user_image";

  static PrefManager? _instance;

  static Future<PrefManager> getInstance() async {
    if (_instance != null) return _instance!;
    _appPref = await SharedPreferences.getInstance();
    _instance = PrefManager();
    return _instance!;
  }

  bool get isLogin {
    return _appPref.getBool(KEY_IS_LOGIN) ?? false;
  }

  set isLogin(bool token) {
    _appPref.setBool(KEY_IS_LOGIN, token);
  }

  String get defaultLan {
    return _appPref.getString(KEY_DEFAULT_LAN) ?? "English";
  }

  set defaultLan(String defaultLan) {
    _appPref.setString(KEY_DEFAULT_LAN, defaultLan);
  }

  String get defaultLanCode {
    return _appPref.getString(KEY_DEFAULT_LAN_CODE) ?? "en";
  }

  set defaultLanCode(String defaultLanCode) {
    _appPref.setString(KEY_DEFAULT_LAN_CODE, defaultLanCode);
  }

  bool get oncePromptAddLoc {
    return _appPref.getBool(KEY_ONCE_PROMPT_TO_ADD_LOCATION) ?? false;
  }

  set oncePromptAddLoc(bool flag) {
    _appPref.setBool(KEY_ONCE_PROMPT_TO_ADD_LOCATION, flag);
  }

  bool get isLocationSelFinish {
    return _appPref.getBool(KEY_IS_LOCATION_SEL_FINISH) ?? false;
  }

  set isLocationSelFinish(bool flag) {
    _appPref.setBool(KEY_IS_LOCATION_SEL_FINISH, flag);
  }

  String? get userEmail => _appPref.getString(KEY_USER_EMAIL);
  set userEmail(String? v) {
    if (v == null) {
      _appPref.remove(KEY_USER_EMAIL);
    } else {
      _appPref.setString(KEY_USER_EMAIL, v);
    }
  }

  String? get userName => _appPref.getString(KEY_USER_NAME);
  set userName(String? v) {
    if (v == null) {
      _appPref.remove(KEY_USER_NAME);
    } else {
      _appPref.setString(KEY_USER_NAME, v);
    }
  }

  String? get userRole => _appPref.getString(KEY_USER_ROLE);
  set userRole(String? v) {
    if (v == null) {
      _appPref.remove(KEY_USER_ROLE);
    } else {
      _appPref.setString(KEY_USER_ROLE, v);
    }
  }

  String? get userPhone => _appPref.getString(KEY_USER_PHONE);
  set userPhone(String? v) {
    if (v == null) {
      _appPref.remove(KEY_USER_PHONE);
    } else {
      _appPref.setString(KEY_USER_PHONE, v);
    }
  }

  Future<void> logout() async {
    isLogin = false;
    userEmail = null;
    userName = null;
    userRole = null;
    userPhone = null;
    // Clear other keys if necessary
    await _appPref.remove(KEY_USER_ADDRESS);
    await _appPref.remove(KEY_USER_IMAGE);
  }

  String? get userAddress => _appPref.getString(KEY_USER_ADDRESS);
  set userAddress(String? v) {
    if (v == null) {
      _appPref.remove(KEY_USER_ADDRESS);
    } else {
      _appPref.setString(KEY_USER_ADDRESS, v);
    }
  }

  String? get userImage => _appPref.getString(KEY_USER_IMAGE);
  set userImage(String? v) {
    if (v == null) {
      _appPref.remove(KEY_USER_IMAGE);
    } else {
      _appPref.setString(KEY_USER_IMAGE, v);
    }
  }
}
