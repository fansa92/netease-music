import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volume_controller/volume_controller.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/now_playing_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../widgets/cover_image.dart';

/// 是否桌面端（Windows/macOS/Linux）
bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// 播放页（xyzfm 播放器效果 + 逻辑）：
/// 大圆角封面、标题/歌手、细进度条 + 已播/剩余时间、大播放控制按钮、
/// 倍速/播放模式/音质，Tab 切换[封面|歌词]。
/// 另有：波形进度条（设置中开启）、移动端音量条、桌面端左右分栏。
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isFavorite = false;
  int? _lastSongId;

  static const _speeds = [1.0, 1.25, 1.5, 2.0, 0.75];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 播放页打开时刷一次锁屏信息，防止系统侧失效
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NowPlayingService.instance?.refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 歌曲变化时同步收藏状态
  void _syncSongState(Song song) {
    if (song.id == _lastSongId) return;
    _lastSongId = song.id;
    _isFavorite = false;
    final auth = context.read<AuthService>();
    final uid = auth.userId;
    if (!auth.loggedIn || uid == null) return;
    // 用喜欢列表判断（失败则保持未收藏显示）
    context.read<MusicService>().likeList(uid).then((ids) {
      if (!mounted || song.id != _lastSongId) return;
      setState(() => _isFavorite = ids.contains(song.id));
    }).catchError((_) {});
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleFavorite(Song song) async {
    final auth = context.read<AuthService>();
    if (!auth.loggedIn) {
      if (mounted) Navigator.of(context).pushNamed('/login');
      return;
    }
    final music = context.read<MusicService>();
    final target = !_isFavorite;
    setState(() => _isFavorite = target);
    try {
      await music.like(song.id, target);
    } catch (e) {
      if (mounted) setState(() => _isFavorite = !target);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('收藏失败：$e')));
      }
    }
  }

  void _cycleSpeed(PlayerService player) {
    final idx = _speeds.indexOf(player.speed);
    final next = _speeds[(idx + 1) % _speeds.length];
    player.setSpeed(next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('倍速 ${next}x'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _showQualitySheet(BuildContext context, PlayerService player) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('音质',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...qualityLevels.entries.map((e) => ListTile(
                  title: Text(e.value),
                  trailing: player.quality == e.key
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    player.setQuality(e.key);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final song = player.current;

    if (song == null) {
      return const Scaffold(
        body: Center(child: Text('暂无播放内容')),
      );
    }
    _syncSongState(song);

    final theme = Theme.of(context);
    final duration =
        player.duration ?? Duration(milliseconds: song.duration);
    final position = player.position;
    final remaining = duration - position;

    return GestureDetector(
      // 移动端下滑关闭播放页
      onVerticalDragEnd: (details) {
        if (!_isDesktop &&
            details.primaryVelocity != null &&
            details.primaryVelocity! > 400) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: TabBar(
            controller: _tabController,
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: '封面'), Tab(text: '歌词')],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showMoreSheet(context, song),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCoverTab(
                context, player, song, duration, position, remaining, theme),
            _LyricView(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverTab(
    BuildContext context,
    PlayerService player,
    Song song,
    Duration duration,
    Duration position,
    Duration remaining,
    ThemeData theme,
  ) {
    // 桌面端宽屏：左封面右歌词
    final isWide =
        MediaQuery.of(context).size.width >= 900 || _isDesktop;
    if (isWide) {
      return Row(
        children: [
          Expanded(child: _buildCoverColumn(context, player, song, duration,
              position, remaining, theme)),
          const VerticalDivider(width: 1),
          const Expanded(child: _LyricView()),
        ],
      );
    }
    return _buildCoverColumn(
        context, player, song, duration, position, remaining, theme);
  }

  Widget _buildCoverColumn(
    BuildContext context,
    PlayerService player,
    Song song,
    Duration duration,
    Duration position,
    Duration remaining,
    ThemeData theme,
  ) {
    final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
    final posMs = position.inMilliseconds.clamp(0, maxMs);
    final waveform =
        context.select<SettingsService, bool>((s) => s.waveformProgress);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // 大圆角封面
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: CoverImage(
                    url: song.picUrl,
                    size: 400,
                    radius: 20,
                  ),
                ),
                const SizedBox(height: 28),
                // 标题 / 歌手
                Text(
                  song.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  song.artistNames,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                // 进度条（波形或细滑杆）
                if (waveform)
                  _WaveformProgress(
                    position: position,
                    duration: duration,
                    songId: song.id,
                    onSeek: (ratio) => player.seek(Duration(
                        milliseconds:
                            (ratio * maxMs).toInt())),
                  )
                else
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12),
                    ),
                    child: Slider(
                      value: posMs.toDouble(),
                      max: maxMs.toDouble(),
                      onChanged: (v) => player
                          .seek(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(position),
                        style: TextStyle(
                            fontSize: 12,
                            color: theme
                                .colorScheme.onSurfaceVariant)),
                    Text(
                        '-${_fmt(remaining.isNegative ? Duration.zero : remaining)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme
                                .colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                // 播放控制
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: () => player.prev(),
                    ),
                    IconButton(
                      iconSize: 64,
                      color: theme.colorScheme.primary,
                      icon: Icon(player.playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill),
                      onPressed: () => player.toggle(),
                    ),
                    IconButton(
                      iconSize: 40,
                      icon: const Icon(Icons.skip_next),
                      onPressed: () => player.next(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 倍速 / 模式 / 音质 / 收藏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => _cycleSpeed(player),
                      child: Text('${player.speed}x',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: player.modeLabel,
                      icon: Icon(
                        switch (player.mode) {
                          PlayMode.sequence => Icons.repeat,
                          PlayMode.loop => Icons.repeat,
                          PlayMode.single => Icons.repeat_one,
                          PlayMode.shuffle => Icons.shuffle,
                        },
                        size: 22,
                      ),
                      onPressed: () {
                        player.cycleMode();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(player.modeLabel),
                            duration:
                                const Duration(milliseconds: 800),
                          ),
                        );
                      },
                    ),
                    TextButton(
                      onPressed: () =>
                          _showQualitySheet(context, player),
                      child: Text(player.qualityLabel,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: '收藏',
                      icon: Icon(
                        _isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 22,
                      ),
                      color: _isFavorite ? Colors.red : null,
                      onPressed: () => _toggleFavorite(song),
                    ),
                  ],
                ),
                // 移动端音量条
                if (!_isDesktop) _VolumeRow(player: player),
                if (player.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      children: [
                        Text(
                          player.errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // 未登录且因无链接被跳过时，给快捷登录入口
                        if (player.errorMessage!.contains('需登录') &&
                            !context
                                .watch<AuthService>()
                                .loggedIn)
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushNamed('/login'),
                            child: const Text('去登录'),
                          ),
                      ],
                    ),
                  ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, Song song) {
    final player = context.read<PlayerService>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('下一首播放'),
              onTap: () {
                Navigator.of(ctx).pop();
                player.playNext(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已添加到下一首播放')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: Text('播放队列（${player.queue.length}）'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showQueueSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.high_quality),
              title: Text('音质：${player.qualityLabel}'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showQualitySheet(context, player);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    final player = context.read<PlayerService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView.builder(
          controller: controller,
          itemCount: player.queue.length,
          itemBuilder: (_, i) {
            final s = player.queue[i];
            final selected = i == player.index;
            return ListTile(
              selected: selected,
              leading:
                  CoverImage(url: s.picUrl, size: 44, radius: 6),
              title: Text(s.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.artistNames,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  player.removeAt(i);
                  Navigator.of(ctx).pop();
                },
              ),
              onTap: () {
                player.jumpTo(i);
                Navigator.of(ctx).pop();
              },
            );
          },
        ),
      ),
    );
  }
}

/// 同步歌词视图
class _LyricView extends StatelessWidget {
  const _LyricView();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        if (player.lyricLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (player.lyrics.isEmpty) {
          return const Center(child: Text('暂无歌词'));
        }
        final idx = player.lyricIndexAt(player.position);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              vertical: 120, horizontal: 32),
          itemCount: player.lyrics.length,
          itemBuilder: (context, i) {
            final line = player.lyrics[i];
            final isCurrent = i == idx;
            final trans = player.transTextOf(i);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isCurrent ? 18 : 15,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                    ),
                  ),
                  if (trans != null && trans.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        trans,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
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
  }
}

/// 移动端音量条（volume_controller）
class _VolumeRow extends StatefulWidget {
  final PlayerService player;
  const _VolumeRow({required this.player});

  @override
  State<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends State<_VolumeRow> {
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    VolumeController.instance.getVolume().then((v) {
      if (mounted) setState(() => _volume = v);
    });
    VolumeController.instance.addListener((v) {
      if (mounted) setState(() => _volume = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.volume_down, size: 20),
          Expanded(
            child: Slider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                VolumeController.instance.setVolume(v);
              },
            ),
          ),
          const Icon(Icons.volume_up, size: 20),
        ],
      ),
    );
  }
}

/// 波形进度条（按歌曲 ID 生成固定波形，点击/拖动跳转）
class _WaveformProgress extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final int songId;
  final ValueChanged<double> onSeek;

  const _WaveformProgress({
    required this.position,
    required this.duration,
    required this.songId,
    required this.onSeek,
  });

  List<double> _bars() {
    final rand = _SeededRandom(songId);
    return List.generate(64, (_) => 0.2 + rand.nextDouble() * 0.8);
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars();
    final maxMs =
        duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
    final ratio =
        (position.inMilliseconds / maxMs).clamp(0.0, 1.0);
    final playedBars = (ratio * bars.length).floor();

    return GestureDetector(
      onTapDown: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onSeek(
            (d.localPosition.dx / box.size.width).clamp(0.0, 1.0));
      },
      onHorizontalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onSeek(
            (d.localPosition.dx / box.size.width).clamp(0.0, 1.0));
      },
      child: SizedBox(
        height: 48,
        child: CustomPaint(
          painter: _WaveformPainter(
            bars: bars,
            playedBars: playedBars,
            color: Theme.of(context).colorScheme.primary,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SeededRandom {
  int _seed;
  _SeededRandom(this._seed);
  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final int playedBars;
  final Color color;

  _WaveformPainter({
    required this.bars,
    required this.playedBars,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / bars.length;
    final playedPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final unplayedPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < bars.length; i++) {
      final h = bars[i] * size.height;
      final x = i * barWidth;
      final y = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              x + barWidth * 0.2, y, barWidth * 0.6, h),
          const Radius.circular(2),
        ),
        i < playedBars ? playedPaint : unplayedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.playedBars != playedBars || old.bars != bars;
}
