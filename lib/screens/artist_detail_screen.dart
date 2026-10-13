import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

/// 歌手详情：热门歌曲 / 专辑 / 简介
class ArtistDetailScreen extends StatefulWidget {
  final int artistId;
  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ArtistDetail? _detail;
  List<AlbumMini>? _albums;
  String? _desc;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final music = context.read<MusicService>();
      final detail = await music.artist(widget.artistId);
      if (!mounted) return;
      setState(() => _detail = detail);
      final albums = await music.artistAlbums(widget.artistId);
      final desc = await music.artistDesc(widget.artistId);
      if (!mounted) return;
      setState(() {
        _albums = albums;
        _desc = desc;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.name ?? '歌手')),
      body: _error != null
          ? Center(child: Text('加载失败：$_error'))
          : detail == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildHeader(detail),
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '热门歌曲'),
                        Tab(text: '专辑'),
                        Tab(text: '简介'),
                      ],
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSongs(detail),
                          _buildAlbums(),
                          _buildDesc(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader(ArtistDetail detail) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipOval(
              child: CoverImage(
                  url: '${detail.picUrl}?param=200y200',
                  size: 88,
                  radius: 44)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  '单曲 ${detail.musicSize} · 专辑 ${detail.albumSize} · MV ${detail.mvSize}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (detail.briefDesc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      detail.briefDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongs(ArtistDetail detail) {
    final songs = detail.hotSongs;
    final player = context.read<PlayerService>();
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, i) => SongTile(
        song: songs[i],
        index: i + 1,
        onTap: () => player.playQueue(songs, i),
      ),
    );
  }

  Widget _buildAlbums() {
    final albums = _albums;
    if (albums == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final a = albums[i];
        return GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/album', arguments: a.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CoverImage(
                      url: a.picUrl, size: double.infinity, radius: 10),
                ),
              ),
              const SizedBox(height: 6),
              Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesc() {
    final desc = _desc;
    if (desc == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(desc,
          style: const TextStyle(fontSize: 14, height: 1.7)),
    );
  }
}

/// 热门歌手列表
class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  Future<List<ArtistMini>>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<MusicService>().hotArtists(limit: 30);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('热门歌手')),
      body: FutureBuilder<List<ArtistMini>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }
          final artists = snapshot.data ?? [];
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: artists.length,
            itemBuilder: (context, i) {
              final a = artists[i];
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/artist',
                    arguments: a.id),
                child: Column(
                  children: [
                    ClipOval(
                        child: CoverImage(
                            url: '${a.picUrl}?param=200y200',
                            size: 88,
                            radius: 44)),
                    const SizedBox(height: 8),
                    Text(a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
