import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../services/settings_service.dart';

/// 设置：接口地址（可填入自建 API）
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _controller = TextEditingController(text: settings.apiBaseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    final err = SettingsService.validateBaseUrl(url);
    setState(() => _error = err);
    if (err != null) return;
    await context.read<SettingsService>().setApiBaseUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('接口地址已更新，立即生效')),
    );
    setState(() {});
  }

  Future<void> _reset() async {
    await context.read<SettingsService>().resetApiBaseUrl();
    _controller.text = ApiClient.defaultBaseUrl;
    setState(() => _error = null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复默认接口地址')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('接口地址',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: cs.primary)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'https://你的接口域名/路径',
              prefixIcon: const Icon(Icons.cloud_outlined),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '当前：${settings.apiBaseUrl}${settings.isDefault ? '（默认）' : ''}\n修改后立即生效；若切换了不同的服务端，建议重新登录。',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('恢复默认'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '默认：${ApiClient.defaultBaseUrl}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 48),
          Text('外观',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: cs.primary)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.palette_outlined,
                  color: Colors.white, size: 22),
            ),
            title: const Text('主题'),
            subtitle: Text(
                settings.dynamicColor
                    ? '动态取色（跟随系统壁纸）'
                    : settings.themeName,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.textSecondary),
            onTap: () => Navigator.pushNamed(context, '/theme'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('波浪形进度条'),
            subtitle: const Text('播放器进度条显示为波形样式',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            value: settings.waveformProgress,
            onChanged: (v) =>
                context.read<SettingsService>().setWaveformProgress(v),
          ),
          const Divider(height: 48),
          Text('关于',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: cs.primary)),
          const SizedBox(height: 8),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.music_note_outlined),
            title: Text('云音乐'),
            subtitle: Text('Flutter 客户端 · Material 3'),
          ),
        ],
      ),
    );
  }
}
