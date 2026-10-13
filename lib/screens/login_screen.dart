import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';

/// 登录页：二维码登录 / 手机号登录
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('登录'),
          bottom: TabBar(
            tabs: [Tab(text: '二维码登录'), Tab(text: '手机号登录')],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        body: const TabBarView(
          children: [_QrLoginTab(), _PhoneLoginTab()],
        ),
      ),
    );
  }
}

/// 二维码登录：手机网易云 App 扫码
class _QrLoginTab extends StatefulWidget {
  const _QrLoginTab();

  @override
  State<_QrLoginTab> createState() => _QrLoginTabState();
}

class _QrLoginTabState extends State<_QrLoginTab> {
  String? _key;
  String? _qrimg;
  String _status = '正在生成二维码…';
  bool _expired = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _newQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _newQr() async {
    _timer?.cancel();
    setState(() {
      _status = '正在生成二维码…';
      _expired = false;
      _qrimg = null;
    });
    try {
      final auth = context.read<AuthService>();
      final key = await auth.qrKey();
      final qr = await auth.qrCreate(key);
      if (!mounted) return;
      setState(() {
        _key = key;
        _qrimg = qr['qrimg'];
        _status = '请使用网易云音乐 App 扫码';
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '生成失败：$e';
          _expired = true;
        });
      }
    }
  }

  Future<void> _check() async {
    if (_key == null) return;
    try {
      final code = await context.read<AuthService>().qrCheck(_key!);
      if (!mounted) return;
      switch (code) {
        case 800:
          _timer?.cancel();
          setState(() {
            _status = '二维码已过期，请刷新';
            _expired = true;
          });
        case 801:
          setState(() => _status = '等待扫码…');
        case 802:
          setState(() => _status = '已扫码，请在手机上确认登录');
        case 803:
          _timer?.cancel();
          setState(() => _status = '登录成功！');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    Widget qrWidget;
    if (_qrimg != null && _qrimg!.contains('base64,')) {
      try {
        final bytes =
            base64Decode(_qrimg!.split('base64,').last);
        qrWidget = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.memory(bytes, width: 220, height: 220),
        );
      } catch (_) {
        qrWidget = const Icon(Icons.qr_code, size: 120);
      }
    } else {
      qrWidget = const SizedBox(
        width: 220,
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          qrWidget,
          const SizedBox(height: 20),
          Text(_status,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          if (_expired)
            ElevatedButton.icon(
              onPressed: _newQr,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新二维码'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// 手机号 + 密码登录（密码经 MD5 后传输）
class _PhoneLoginTab extends StatefulWidget {
  const _PhoneLoginTab();

  @override
  State<_PhoneLoginTab> createState() => _PhoneLoginTabState();
}

class _PhoneLoginTabState extends State<_PhoneLoginTab> {
  final _phoneController = TextEditingController();
  final _pwdController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().phoneLogin(
            _phoneController.text.trim(),
            _pwdController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('登录成功')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('登录失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.music_note,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '手机号',
              prefixIcon: Icon(Icons.phone_android,
                  color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pwdController,
            obscureText: _obscure,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              hintText: '密码',
              prefixIcon: const Icon(Icons.lock_outline,
                  color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('登录', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
          const Text(
            '提示：频繁调用登录接口可能触发网易风控，推荐使用二维码登录。密码仅经 MD5 后传输，不会明文存储。',
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
