import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/mini_player.dart';

/// 全屏播放器：旋转封面 / 同步歌词 / 播放控制
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        final song = player.current;
        if (song == null) {
          return const Scaffold(
            body: Center(child: Text('暂无播放内容')),
          );
        }
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              children: [
                Text(song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16)),
                Text(song.artistNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.normal)),
              ],
            ),
            centerTitle: true,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 模糊背景（Border-Player 质感风格：封面高斯模糊 + 渐变罩）
              if (song.picUrl.isNotEmpty)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: CoverImage(
                      url: song.picUrl, size: double.infinity, radius: 0),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: kToolbarHeight + 8),
                    Expanded(
                      child: PageView(
                        children: [
                          _DiscView(song: song),
                          const _LyricView(),
                        ],
                      ),
                    ),
                    _buildErrorHint(player),
                    _buildQualityRow(context, player),
                    _buildProgress(player),
                    _buildControls(context, player),
                    _buildActions(context, player, song),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorHint(PlayerService player) {
    if (player.errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Text(
        player.errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
      ),
    );
  }

  Widget _buildQualityRow(BuildContext context, PlayerService player) {
    return TextButton(
      onPressed: () => _showQualitySheet(context, player),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(player.qualityLabel,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const Icon(Icons.arrow_drop_down,
                size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showQualitySheet(BuildContext context, PlayerService player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择音质',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...qualityLevels.entries.map((e) => ListTile(
                  title: Text(e.value),
                  trailing: player.quality == e.key
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    player.setQuality(e.key);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(PlayerService player) {
    return StreamBuilder<Duration>(
      stream: player.player.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final total = player.player.duration ?? Duration.zero;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(_fmt(pos),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white60)),
              Expanded(
                child: Slider(
                  value: pos.inMilliseconds
                      .clamp(0, total.inMilliseconds)
                      .toDouble(),
                  max: (total.inMilliseconds > 0
                          ? total.inMilliseconds
                          : 1)
                      .toDouble(),
                  onChanged: (v) =>
                      player.seek(Duration(milliseconds: v.toInt())),
                ),
              ),
              Text(_fmt(total),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.white60)),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildControls(BuildContext context, PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_modeIcon(player.mode), color: Colors.white70),
            tooltip: player.modeLabel,
            onPressed: () {
              player.cycleMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(player.modeLabel),
                    duration: const Duration(milliseconds: 800)),
              );
            },
          ),
          IconButton(
            icon:
                const Icon(Icons.skip_previous, size: 40, color: Colors.white),
            onPressed: player.prev,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                player.playing ? Icons.pause : Icons.play_arrow,
                size: 36,
                color: Colors.black87,
              ),
              onPressed: player.toggle,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, size: 40, color: Colors.white),
            onPressed: player.next,
          ),
          IconButton(
            icon: const Icon(Icons.queue_music, color: Colors.white70),
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.bg,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (_) => const QueueSheet(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(
      BuildContext context, PlayerService player, Song song) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _LikeButton(song: song),
        IconButton(
          icon: const Icon(Icons.comment_outlined, color: Colors.white70),
          onPressed: () =>
              Navigator.pushNamed(context, '/comments', arguments: song),
        ),
        IconButton(
          icon: const Icon(Icons.playlist_add, color: Colors.white70),
          onPressed: () => player.playNext(song),
          tooltip: '下一首播放',
        ),
      ],
    );
  }

  IconData _modeIcon(PlayMode mode) => switch (mode) {
        PlayMode.sequence => Icons.arrow_forward,
        PlayMode.loop => Icons.repeat,
        PlayMode.single => Icons.repeat_one,
        PlayMode.shuffle => Icons.shuffle,
      };
}

/// 旋转黑胶封面
class _DiscView extends StatefulWidget {
  final Song song;
  const _DiscView({required this.song});

  @override
  State<_DiscView> createState() => _DiscViewState();
}

class _DiscViewState extends State<_DiscView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    final playing = context.read<PlayerService>().playing;
    if (playing) _controller.repeat();
    _sub = context
        .read<PlayerService>()
        .player
        .playerStateStream
        .listen((state) {
      if (!mounted) return;
      if (state.playing) {
        if (!_controller.isAnimating) _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          RotationTransition(
            turns: _controller,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: CoverImage(
                    url: widget.song.picUrl, size: 280, radius: 140),
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Icon(Icons.music_note,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

/// 同步歌词视图
class _LyricView extends StatefulWidget {
  const _LyricView();

  @override
  State<_LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<_LyricView> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -2;
  static const double _itemHeight = 62;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(int index, int count) {
    if (!_scrollController.hasClients || index < 0) return;
    final target =
        (index * _itemHeight - 200).clamp(0.0, _itemHeight * count);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        if (player.lyricLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (player.lyrics.isEmpty) {
          return const Center(
            child: Text('暂无歌词',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          );
        }
        return StreamBuilder<Duration>(
          stream: player.player.positionStream,
          builder: (context, snapshot) {
            final pos = snapshot.data ?? Duration.zero;
            final current = player.lyricIndexAt(pos);
            if (current != _lastIndex) {
              _lastIndex = current;
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollTo(current, player.lyrics.length));
            }
            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 220),
              itemCount: player.lyrics.length,
              itemBuilder: (context, i) {
                final line = player.lyrics[i];
                final isCurrent = i == current;
                final trans = player.transTextOf(i);
                return SizedBox(
                  height: _itemHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        line.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCurrent ? 17 : 14,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white60,
                        ),
                      ),
                      if (trans != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            trans,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isCurrent
                                  ? Colors.white70
                                  : Colors.white38,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 喜欢 / 取消喜欢按钮
class _LikeButton extends StatefulWidget {
  final Song song;
  const _LikeButton({required this.song});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  bool _liked = false;
  bool _busy = false;

  void _toggle() async {
    final auth = context.read<AuthService>();
    if (!auth.loggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('喜欢音乐需要登录'),
          action: SnackBarAction(
            label: '去登录',
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
        ),
      );
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context
          .read<MusicService>()
          .like(widget.song.id, !_liked);
      setState(() => _liked = !_liked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_liked ? '已添加到我喜欢的音乐' : '已取消喜欢'),
              duration: const Duration(milliseconds: 800)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _liked ? Icons.favorite : Icons.favorite_border,
        color: _liked ? Theme.of(context).colorScheme.primary : Colors.white70,
      ),
      onPressed: _toggle,
    );
  }
}
