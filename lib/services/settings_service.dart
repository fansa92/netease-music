import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';

/// 应用设置：目前管理「接口地址」，持久化到 SharedPreferences，
/// 修改后立即作用到 [ApiClient]，无需重启。
class SettingsService extends ChangeNotifier {
  static const _keyApiBaseUrl = 'api_base_url';
  static const _keyDynamicColor = 'dynamic_color';
  static const _keyThemeSeed = 'theme_seed';
  static const _keyBlogUrl = 'blog_url';

  /// 预设主题色
  static const List<ThemePreset> themePresets = [
    ThemePreset('网易云红', 0xFFD33A31),
    ThemePreset('活力橙', 0xFFF57C00),
    ThemePreset('琥珀黄', 0xFFFFB300),
    ThemePreset('草原绿', 0xFF4CAF50),
    ThemePreset('湖水青', 0xFF00BCD4),
    ThemePreset('天空蓝', 0xFF2196F3),
    ThemePreset('靛蓝', 0xFF3F51B5),
    ThemePreset('葡萄紫', 0xFF9C27B0),
    ThemePreset('樱花粉', 0xFFE91E63),
  ];
  static const int defaultThemeSeed = 0xFFD33A31;

  final ApiClient _api;
  late SharedPreferences _prefs;

  String _apiBaseUrl = ApiClient.defaultBaseUrl;
  String get apiBaseUrl => _apiBaseUrl;
  bool get isDefault => _apiBaseUrl == ApiClient.defaultBaseUrl;

  /// 博客地址（侧栏「博客」页面加载的 URL）
  String _blogUrl = '';
  String get blogUrl => _blogUrl;

  /// M3 动态取色（跟随系统壁纸，Android 12+ 有效），默认开启
  bool _dynamicColor = true;
  bool get dynamicColor => _dynamicColor;

  /// 从系统取到的动态配色；不支持或未取到时为 null
  ColorScheme? _systemScheme;
  ColorScheme? get systemScheme => _systemScheme;

  /// 当前生效的配色：动态取色开且系统支持时用系统色，
  /// 否则用用户选的主题色（默认网易云红时返回 null，走默认配色）
  ColorScheme? get effectiveScheme {
    if (_dynamicColor && _systemScheme != null) return _systemScheme;
    if (_themeSeed != defaultThemeSeed) {
      return ColorScheme.fromSeed(
        seedColor: Color(_themeSeed),
        brightness: Brightness.dark,
      );
    }
    return null;
  }

  /// 主题色（ARGB int），默认网易云红
  int _themeSeed = defaultThemeSeed;
  int get themeSeed => _themeSeed;
  String get themeName => themePresets
      .firstWhere((p) => p.value == _themeSeed,
          orElse: () => themePresets.first)
      .name;

  SettingsService(this._api);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = _prefs.getString(_keyApiBaseUrl) ?? ApiClient.defaultBaseUrl;
    _api.setBaseUrl(_apiBaseUrl);
    _themeSeed = _prefs.getInt(_keyThemeSeed) ?? defaultThemeSeed;
    _blogUrl = _prefs.getString(_keyBlogUrl) ?? '';
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

  Future<void> setBlogUrl(String url) async {
    url = url.trim();
    if (url == _blogUrl) return;
    _blogUrl = url;
    await _prefs.setString(_keyBlogUrl, url);
    notifyListeners();
  }

  Future<void> setDynamicColor(bool value) async {
    if (value == _dynamicColor) return;
    _dynamicColor = value;
    await _prefs.setBool(_keyDynamicColor, value);
    if (value && _systemScheme == null) await _loadSystemScheme();
    notifyListeners();
  }

  /// 选择预设主题色：同时关闭动态取色（手动选色优先）
  Future<void> setThemeSeed(int value) async {
    if (value == _themeSeed) return;
    _themeSeed = value;
    await _prefs.setInt(_keyThemeSeed, value);
    if (_dynamicColor) {
      _dynamicColor = false;
      await _prefs.setBool(_keyDynamicColor, false);
    }
    notifyListeners();
  }
}

/// 主题预设
class ThemePreset {
  final String name;
  final int value;
  const ThemePreset(this.name, this.value);
}
