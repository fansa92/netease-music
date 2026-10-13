import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/playlist_card.dart';
import '../widgets/section_header.dart';
import '../widgets/song_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  final List<BannerItem> banners;
  final List<Playlist> playlists;
  final List<Song> newSongs;
  final List<Playlist> toplists;
  final List<ArtistMini> artists;

  _HomeData({
    required this.banners,
    required this.playlists,
    required this.newSongs,
    required this.toplists,
    required this.artists,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  Future<_HomeData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final music = context.read<MusicService>();
    final results = await Future.wait([
      music.banners(),
      music.personalized(limit: 12),
      music.newSongs(limit: 10),
      music.toplists(),
      music.hotArtists(limit: 12),
    ]);
    return _HomeData(
      banners: results[0] as List<BannerItem>,
      playlists: results[1] as List<Playlist>,
      newSongs: results[2] as List<Song>,
      toplists: results[3] as List<Playlist>,
      artists: results[4] as List<ArtistMini>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _refresh,
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text('加载失败：${snapshot.error}',
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.data!;
            return CustomScrollView(
              slivers: [
                _buildHeader(context),
                SliverToBoxAdapter(child: _BannerCarousel(banners: data.banners)),
                SliverToBoxAdapter(child: _buildNavRow(context)),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: '推荐歌单',
                    onMore: () => Navigator.pushNamed(context, '/toplist'),
                  ),
                ),
                SliverToBoxAdapter(child: _buildPlaylistRow(data.playlists)),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: '推荐新歌',
                    onMore: () => Navigator.pushNamed(context, '/songlist',
                        arguments: {
                          'title': '新歌速递',
                          'loader': 'newsong',
                        }),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final song = data.newSongs[i];
                      return SongTile(
                        song: song,
                        showPic: true,
                        onTap: () => context
                            .read<PlayerService>()
                            .playQueue(data.newSongs, i),
                      );
                    },
                    childCount: data.newSongs.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: '排行榜',
                    onMore: () =>
                        Navigator.pushNamed(context, '/toplist'),
                  ),
                ),
                SliverToBoxAdapter(child: _buildToplistRow(data.toplists)),
                SliverToBoxAdapter(
                    child: SectionHeader(title: '热门歌手')),
                SliverToBoxAdapter(child: _buildArtistRow(data.artists)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB32B26), Color(0xFFD33A31)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                const Icon(Icons.music_note, color: Colors.white, size: 26),
                const SizedBox(width: 8),
                const Text(
                  '云音乐',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/search',
                        arguments: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search,
                              size: 18, color: Colors.white70),
                          SizedBox(width: 6),
                          Text('搜索歌曲、歌手、歌单',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavRow(BuildContext context) {
    final auth = context.watch<AuthService>();
    final items = [
      _NavItem(
        icon: Icons.calendar_today,
        label: '每日推荐',
        onTap: () {
          if (!auth.loggedIn) {
            _needLogin(context);
            return;
          }
          Navigator.pushNamed(context, '/songlist',
              arguments: {'title': '每日推荐', 'loader': 'recommend'});
        },
      ),
      _NavItem(
        icon: Icons.leaderboard_outlined,
        label: '排行榜',
        onTap: () => Navigator.pushNamed(context, '/toplist'),
      ),
      _NavItem(
        icon: Icons.mic_outlined,
        label: '热门歌手',
        onTap: () => Navigator.pushNamed(context, '/artists'),
      ),
      _NavItem(
        icon: Icons.new_releases_outlined,
        label: '新歌速递',
        onTap: () => Navigator.pushNamed(context, '/songlist',
            arguments: {'title': '新歌速递', 'loader': 'newsong'}),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items
            .map((e) => GestureDetector(
                  onTap: e.onTap,
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(e.icon,
                            color: Theme.of(context).colorScheme.primary, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(e.label,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildPlaylistRow(List<Playlist> playlists) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) =>
            PlaylistCard(playlist: playlists[i]),
      ),
    );
  }

  Widget _buildToplistRow(List<Playlist> toplists) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: toplists.length.clamp(0, 8),
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final t = toplists[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/playlist',
                arguments: t.id),
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CoverImage(url: t.coverUrl, size: 84, radius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        ...t.trackPreviews.take(3).map(
                              (p) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  p,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistRow(List<ArtistMini> artists) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: artists.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = artists[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/artist',
                arguments: a.id),
            child: Column(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: a.picUrl.isEmpty
                        ? Container(
                            color: AppColors.card,
                            child: const Icon(Icons.person,
                                color: AppColors.textSecondary),
                          )
                        : CoverImage(
                            url: thumb(a.picUrl, 128),
                            size: 64,
                            radius: 32),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 72,
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _needLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('该功能需要登录'),
        action: SnackBarAction(
          label: '去登录',
          onPressed: () => Navigator.pushNamed(context, '/login'),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _NavItem({required this.icon, required this.label, required this.onTap});
}

/// 轮播图
class _BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;
  const _BannerCarousel({required this.banners});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.banners.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap(BannerItem banner) async {
    final music = context.read<MusicService>();
    final player = context.read<PlayerService>();
    try {
      if (banner.targetType == 1000 || banner.targetType == 1004) {
        Navigator.pushNamed(context, '/playlist', arguments: banner.targetId);
      } else if (banner.targetType == 10) {
        Navigator.pushNamed(context, '/album', arguments: banner.targetId);
      } else if (banner.targetType == 1) {
        final songs = await music.songDetail([banner.targetId]);
        if (songs.isNotEmpty && mounted) {
          await player.playQueue(songs, 0);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('打开失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              final b = widget.banners[i];
              return GestureDetector(
                onTap: () => _onTap(b),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CoverImage(
                            url: b.pic, size: double.infinity, radius: 12),
                      ),
                      if (b.typeTitle.isNotEmpty)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              b.typeTitle,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
            (i) => Container(
              width: i == _current ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == _current
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
