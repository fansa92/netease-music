import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/music_service.dart';
import '../widgets/cover_image.dart';

/// 排行榜列表
class ToplistScreen extends StatefulWidget {
  const ToplistScreen({super.key});

  @override
  State<ToplistScreen> createState() => _ToplistScreenState();
}

class _ToplistScreenState extends State<ToplistScreen> {
  Future<List<Playlist>>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<MusicService>().toplists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('排行榜')),
      body: FutureBuilder<List<Playlist>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }
          final lists = snapshot.data ?? [];
          return ListView.separated(
            itemCount: lists.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) {
              final t = lists[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                leading:
                    CoverImage(url: t.coverUrl, size: 64, radius: 8),
                title: Text(t.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    ...t.trackPreviews.take(3).map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              p,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => Navigator.pushNamed(context, '/playlist',
                    arguments: t.id),
              );
            },
          );
        },
      ),
    );
  }
}
