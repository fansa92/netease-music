import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

/// 专辑详情
class AlbumDetailScreen extends StatefulWidget {
  final int albumId;
  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  AlbumMini? _album;
  List<Song>? _songs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (album, songs) =
          await context.read<MusicService>().album(widget.albumId);
      if (mounted) {
        setState(() {
          _album = album;
          _songs = songs;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final album = _album;
    final songs = _songs;
    return Scaffold(
      appBar: AppBar(title: Text(album?.name ?? '专辑')),
      body: _error != null
          ? Center(child: Text('加载失败：$_error'))
          : album == null || songs == null
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CoverImage(
                                url: album.picUrl, size: 120, radius: 10),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(album.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(album.artistNames,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color:
                                              AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_filled,
                            color: AppColors.primary, size: 30),
                        title: Text('播放全部（${songs.length}）',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        onTap: () => context
                            .read<PlayerService>()
                            .playQueue(songs, 0),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider()),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => SongTile(
                          song: songs[i],
                          index: i + 1,
                          showDuration: true,
                          onTap: () => context
                              .read<PlayerService>()
                              .playQueue(songs, i),
                        ),
                        childCount: songs.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
    );
  }
}
