import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

/// 歌单详情：封面头图 + 歌曲列表
class PlaylistDetailScreen extends StatefulWidget {
  final int playlistId;
  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _playlist;
  List<Song>? _tracks;
  String? _error;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final music = context.read<MusicService>();
      final detail = await music.playlistDetail(widget.playlistId);
      List<Song> tracks = detail.tracks;
      // detail 只返回前 100 首，拉全量
      if (detail.trackCount > tracks.length) {
        tracks = await music.playlistTracks(widget.playlistId);
      }
      if (mounted) {
        setState(() {
          _playlist = detail;
          _tracks = tracks;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _toggleSubscribe() async {
    final auth = context.read<AuthService>();
    if (!auth.loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('收藏歌单需要登录'),
          action: SnackBarAction(
            label: '去登录',
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
      );
      return;
    }
    try {
      await context
          .read<MusicService>()
          .playlistSubscribe(widget.playlistId, !_subscribed);
      setState(() => _subscribed = !_subscribed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_subscribed ? '已收藏' : '已取消收藏')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    final tracks = _tracks;
    return Scaffold(
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败：$_error'),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _load();
                    },
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : playlist == null || tracks == null
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 250,
                      pinned: true,
                      actions: [
                        IconButton(
                          icon: Icon(
                            _subscribed
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _subscribed
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                          ),
                          onPressed: _toggleSubscribe,
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 背景模糊封面
                            if (playlist.coverUrl.isNotEmpty)
                              CoverImage(
                                  url: playlist.coverUrl,
                                  size: double.infinity,
                                  radius: 0),
                            Container(
                                color: Colors.black.withValues(alpha: 0.55)),
                            SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, kToolbarHeight + 8, 16, 16),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    CoverImage(
                                        url: playlist.coverUrl,
                                        size: 120,
                                        radius: 10),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playlist.name,
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (playlist.creator != null)
                                            Row(
                                              children: [
                                                ClipOval(
                                                  child: CoverImage(
                                                    url: playlist.creator!
                                                        .avatarUrl,
                                                    size: 24,
                                                    radius: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    playlist.creator!
                                                        .nickname,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '播放 ${formatPlayCount(playlist.playCount)} · ${playlist.trackCount}首',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                          if (playlist.description.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                      top: 6),
                                              child: Text(
                                                playlist.description,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white60,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ListTile(
                        leading: Icon(Icons.play_circle_filled,
                            color: Theme.of(context).colorScheme.primary, size: 30),
                        title: Text(
                            '播放全部（${tracks.length}）',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () => context
                            .read<PlayerService>()
                            .playQueue(tracks, 0),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider()),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final song = tracks[i];
                          return SongTile(
                            song: song,
                            index: i + 1,
                            showDuration: true,
                            onTap: () => context
                                .read<PlayerService>()
                                .playQueue(tracks, i),
                          );
                        },
                        childCount: tracks.length,
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 24)),
                  ],
                ),
    );
  }
}
