import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/utils.dart';

/// 登录状态管理：二维码登录 / 手机号登录，cookie 持久化。
class AuthService extends ChangeNotifier {
  final ApiClient api;

  bool loading = true;
  bool loggedIn = false;
  Map<String, dynamic>? profile;
  Map<String, dynamic>? account;

  AuthService(this.api);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getString('cookie');
    if (c != null && c.isNotEmpty) {
      api.cookie = c;
      await refreshStatus();
    }
    loading = false;
    notifyListeners();
  }

  /// 校验当前 cookie 是否仍然有效
  Future<bool> refreshStatus() async {
    try {
      final data = await api.get('/login/status');
      final d = data['data'];
      if (d is Map &&
          intOf(d['code']) == 200 &&
          d['profile'] is Map &&
          (d['profile'] as Map).isNotEmpty) {
        profile = Map<String, dynamic>.from(d['profile'] as Map);
        account = d['account'] is Map
            ? Map<String, dynamic>.from(d['account'] as Map)
            : null;
        loggedIn = true;
      } else {
        _clearState();
      }
    } catch (_) {
      _clearState();
    }
    notifyListeners();
    return loggedIn;
  }

  void _clearState() {
    loggedIn = false;
    profile = null;
    account = null;
  }

  // ---------- 二维码登录 ----------

  Future<String> qrKey() async {
    final data = await api.get('/login/qr/key');
    final key = data['data']?['unikey'];
    if (key == null || '$key'.isEmpty) throw Exception('获取二维码 key 失败');
    return '$key';
  }

  /// 返回 {'qrurl': ..., 'qrimg': 'data:image/png;base64,...'}
  Future<Map<String, String>> qrCreate(String key) async {
    final data = await api.get('/login/qr/create', {'key': key, 'qrimg': true});
    final d = data['data'] as Map?;
    if (d == null) throw Exception('生成二维码失败');
    return {'qrurl': '${d['qrurl'] ?? ''}', 'qrimg': '${d['qrimg'] ?? ''}'};
  }

  /// 轮询扫码状态：
  /// 800 二维码过期，801 等待扫码，802 待确认，803 登录成功
  Future<int> qrCheck(String key) async {
    final data = await api.get('/login/qr/check', {'key': key});
    final code = intOf(data['code']);
    if (code == 803) {
      final cookie = data['cookie'] as String?;
      if (cookie != null && cookie.isNotEmpty) {
        await _saveCookie(cookie);
        await refreshStatus();
      }
    }
    return code;
  }

  // ---------- 手机号登录 ----------

  Future<void> phoneLogin(String phone, String password) async {
    if (phone.isEmpty || password.isEmpty) {
      throw Exception('请输入手机号和密码');
    }
    final md5pwd = md5.convert(utf8.encode(password)).toString();
    final data =
        await api.get('/login/cellphone', {'phone': phone, 'password': md5pwd});
    if (intOf(data['code']) != 200) {
      throw Exception('${data['message'] ?? data['msg'] ?? '登录失败'}');
    }
    final cookie = data['cookie'] as String?;
    if (cookie == null || cookie.isEmpty) {
      throw Exception('登录成功但未获取到凭证，请重试');
    }
    await _saveCookie(cookie);
    await refreshStatus();
    if (!loggedIn) throw Exception('登录状态校验失败，请重试');
  }

  Future<void> _saveCookie(String cookie) async {
    api.cookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookie', cookie);
  }

  Future<void> logout() async {
    try {
      await api.get('/logout');
    } catch (_) {}
    api.cookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cookie');
    _clearState();
    notifyListeners();
  }

  // ---------- 便捷访问 ----------

  int? get userId {
    final id = profile?['userId'] ?? account?['id'];
    if (id == null) return null;
    return intOf(id);
  }

  String get nickname => '${profile?['nickname'] ?? ''}';
  String get signature => '${profile?['signature'] ?? ''}';
  String get avatarUrl => httpsUrl(profile?['avatarUrl'] as String?);
  int get vipType => intOf(profile?['vipType']);
}
