import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';

/// 应用设置：目前管理「接口地址」，持久化到 SharedPreferences，
/// 修改后立即作用到 [ApiClient]，无需重启。
class SettingsService extends ChangeNotifier {
  static const _keyApiBaseUrl = 'api_base_url';

  final ApiClient _api;
  late SharedPreferences _prefs;

  String _apiBaseUrl = ApiClient.defaultBaseUrl;
  String get apiBaseUrl => _apiBaseUrl;
  bool get isDefault => _apiBaseUrl == ApiClient.defaultBaseUrl;

  SettingsService(this._api);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _apiBaseUrl =
        _prefs.getString(_keyApiBaseUrl) ?? ApiClient.defaultBaseUrl;
    _api.setBaseUrl(_apiBaseUrl);
  }

  /// 校验通过返回 null，否则返回错误信息。
  static String? validateBaseUrl(String url) {
    url = url.trim();
    if (url.isEmpty) return '接口地址不能为空';
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return '请输入以 http:// 或 https:// 开头的地址';
    }
    return null;
  }

  Future<void> setApiBaseUrl(String url) async {
    url = url.trim();
    if (url.isEmpty || url == _apiBaseUrl) return;
    _apiBaseUrl = url;
    _api.setBaseUrl(url);
    await _prefs.setString(_keyApiBaseUrl, url);
    notifyListeners();
  }

  Future<void> resetApiBaseUrl() => setApiBaseUrl(ApiClient.defaultBaseUrl);
}
