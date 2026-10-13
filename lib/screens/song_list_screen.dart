import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/song_tile.dart';

/// 通用歌曲列表页：每日推荐 / 新歌速递 / 我喜欢的音乐
///
/// arguments: {'title': String, 'loader': 'recommend' | 'newsong' | 'liked'}
class SongListScreen extends StatefulWidget {
  final String title;
  final String loader;
  const SongListScreen(
      {super.key, required this.title, required this.loader});

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  Future<List<Song>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Song>> _load() async {
    final music = context.read<MusicService>();
    switch (widget.loader) {
      case 'recommend':
        return music.recommendSongs();
      case 'newsong':
        return music.newSongs(limit: 50);
      case 'liked':
        final auth = context.read<AuthService>();
        final uid = auth.userId;
        if (uid == null) throw Exception('需要登录');
        final ids = await music.likeList(uid);
        final songs = <Song>[];
        // 分批拉取详情，避免 url 过长
        for (var i = 0; i < ids.length; i += 100) {
          final chunk = ids.sublist(
              i, (i + 100).clamp(0, ids.length));
          songs.addAll(await music.songDetail(chunk));
        }
        return songs;
      default:
        throw Exception('未知列表类型');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败：${snapshot.error}',
                      style: const TextStyle(
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        setState(() => _future = _load()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          final songs = snapshot.data ?? [];
          if (songs.isEmpty) {
            return const Center(
                child: Text('暂无歌曲',
                    style:
                        TextStyle(color: AppColors.textSecondary)));
          }
          final player = context.read<PlayerService>();
          return Column(
            children: [
              ListTile(
                leading: Icon(Icons.play_circle_filled,
                    color: Theme.of(context).colorScheme.primary, size: 30),
                title: Text('播放全部（${songs.length}）',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => player.playQueue(songs, 0),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) => SongTile(
                    song: songs[i],
                    index: i + 1,
                    onTap: () => player.playQueue(songs, i),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
