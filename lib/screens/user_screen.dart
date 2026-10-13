import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../widgets/cover_image.dart';

/// 我的：登录态 / 个人歌单 / 退出登录
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  Future<_UserData>? _future;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    if (auth.loggedIn && auth.userId != null) {
      _future = _load(auth.userId!);
    }
    // 登录状态变化时刷新
    auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    context.read<AuthService>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final auth = context.read<AuthService>();
    if (!mounted) return;
    setState(() {
      if (auth.loggedIn && auth.userId != null) {
        _future = _load(auth.userId!);
      } else {
        _future = null;
      }
    });
  }

  Future<_UserData> _load(int uid) async {
    final music = context.read<MusicService>();
    final results = await Future.wait([
      music.userDetail(uid),
      music.userPlaylists(uid),
    ]);
    return _UserData(
      detail: results[0] as Map<String, dynamic>,
      playlists: results[1] as List<Playlist>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!auth.loggedIn) return _buildLoginPrompt(context);
          final future = _future;
          if (future == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<_UserData>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                    child: Text('加载失败：${snapshot.error}'));
              }
              return _buildUser(context, auth, snapshot.data!);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person,
                size: 44, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text('登录后可同步歌单、听歌排行',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 48, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('立即登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildUser(
      BuildContext context, AuthService auth, _UserData data) {
    final uid = auth.userId!;
    final level = intOf(data.detail['level']);
    final listenSongs = intOf(data.detail['listenSongs']);

    final created = data.playlists
        .where((p) => p.creator?.userId == uid)
        .toList();
    final collected = data.playlists
        .where((p) => p.creator?.userId != uid)
        .toList();

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipOval(
                  child: CoverImage(
                      url: auth.avatarUrl, size: 72, radius: 36)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.nickname,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold)),
                    if (auth.signature.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(auth.signature,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _statChip('Lv.$level'),
                        const SizedBox(width: 8),
                        _statChip(
                            '累计听歌 $listenSongs 首'),
                        if (auth.vipType > 0) ...[
                          const SizedBox(width: 8),
                          _statChip('VIP',
                              highlight: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.favorite,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('我喜欢的音乐'),
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textSecondary),
          onTap: () => Navigator.pushNamed(context, '/songlist',
              arguments: {
                'title': '我喜欢的音乐',
                'loader': 'liked'
              }),
        ),
        ListTile(
          leading: Icon(Icons.calendar_today,
              color: Theme.of(context).colorScheme.primary),
          title: const Text('每日推荐歌曲'),
          trailing: const Icon(Icons.chevron_right,
              color: AppColors.textSecondary),
          onTap: () => Navigator.pushNamed(context, '/songlist',
              arguments: {
                'title': '每日推荐',
                'loader': 'recommend'
              }),
        ),
        const Divider(),
        if (created.isNotEmpty) ...[
          _sectionTitle('创建的歌单（${created.length}）'),
          ...created.map(_playlistTile),
        ],
        if (collected.isNotEmpty) ...[
          _sectionTitle('收藏的歌单（${collected.length}）'),
          ...collected.map(_playlistTile),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: OutlinedButton(
            onPressed: () => _confirmLogout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('退出登录'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _statChip(String text, {bool highlight = false}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : AppColors.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: highlight
              ? Theme.of(context).colorScheme.primary
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _playlistTile(Playlist p) {
    return ListTile(
      leading: CoverImage(url: p.coverUrl, size: 52, radius: 8),
      title: Text(p.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${p.trackCount}首 · 播放${formatPlayCount(p.playCount)}',
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textSecondary),
      onTap: () =>
          Navigator.pushNamed(context, '/playlist', arguments: p.id),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthService>().logout();
    }
  }
}

class _UserData {
  final Map<String, dynamic> detail;
  final List<Playlist> playlists;
  _UserData({required this.detail, required this.playlists});
}
