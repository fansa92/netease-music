import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';

/// 应用设置：目前管理「接口地址」，持久化到 SharedPreferences，
/// 修改后立即作用到 [ApiClient]，无需重启。
class SettingsService extends ChangeNotifier {
  static const _keyApiBaseUrl = 'api_base_url';
  static const _keyDynamicColor = 'dynamic_color';

  final ApiClient _api;
  late SharedPreferences _prefs;

  String _apiBaseUrl = ApiClient.defaultBaseUrl;
  String get apiBaseUrl => _apiBaseUrl;
  bool get isDefault => _apiBaseUrl == ApiClient.defaultBaseUrl;

  /// M3 动态取色（跟随系统壁纸，Android 12+ 有效），默认开启
  bool _dynamicColor = true;
  bool get dynamicColor => _dynamicColor;

  /// 从系统取到的动态配色；不支持或未取到时为 null
  ColorScheme? _systemScheme;
  ColorScheme? get systemScheme => _systemScheme;

  /// 当前生效的配色：动态取色开且系统支持时用系统色，否则 null（默认网易云红）
  ColorScheme? get effectiveScheme => _dynamicColor ? _systemScheme : null;

  SettingsService(this._api);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = _prefs.getString(_keyApiBaseUrl) ?? ApiClient.defaultBaseUrl;
    _api.setBaseUrl(_apiBaseUrl);
    _dynamicColor = _prefs.getBool(_keyDynamicColor) ?? true;
    if (_dynamicColor) await _loadSystemScheme();
  }

  /// 通过系统 CorePalette 生成 M3 深色动态配色
  Future<void> _loadSystemScheme() async {
    try {
      final palette = await DynamicColorPlugin.getCorePalette();
      if (palette != null) {
        _systemScheme = ColorScheme.fromSeed(
          seedColor: Color(palette.primary.get(40)),
          brightness: Brightness.dark,
        );
      }
    } catch (_) {
      _systemScheme = null;
    }
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

  Future<void> setDynamicColor(bool value) async {
    if (value == _dynamicColor) return;
    _dynamicColor = value;
    await _prefs.setBool(_keyDynamicColor, value);
    if (value && _systemScheme == null) await _loadSystemScheme();
    notifyListeners();
  }
}
