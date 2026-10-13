import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme.dart';
import '../services/settings_service.dart';

/// 博客页面：内嵌 WebView，地址在「设置」里配置
class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  WebViewController? _controller;
  String? _loadedUrl;

  @override
  Widget build(BuildContext context) {
    final url = context.watch<SettingsService>().blogUrl.trim();
    if (url.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('博客')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rss_feed,
                  size: 56, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('还没有设置博客地址',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/settings'),
                child: const Text('去设置'),
              ),
            ],
          ),
        ),
      );
    }
    if (_controller == null || _loadedUrl != url) {
      _loadedUrl = url;
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(url));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('博客'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller!),
    );
  }
}
