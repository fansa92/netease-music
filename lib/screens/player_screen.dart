import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volume_controller/volume_controller.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/mini_player.dart';

/// 是否桌面端（Windows/macOS/Linux）
bool get _isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// 全屏播放器：Apple Music 风格
/// 方形大封面 / 左对齐歌名歌手 / 细进度条 / 大按钮 / 音量条 / 同步歌词
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
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 模糊背景：封面高斯模糊 + 渐变罩
              if (song.picUrl.isNotEmpty)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                  child: CoverImage(
                      url: song.picUrl, size: double.infinity, radius: 0),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 桌面端宽屏：左封面右歌词；移动端：滑动切换
                          final isWide =
                              constraints.maxWidth >= 900 || _isDesktop;
                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _ArtworkView(song: song),
                                ),
                                const VerticalDivider(
                                    width: 1, color: Colors.white12),
                                const Expanded(
                                  child: _LyricView(),
                                ),
                              ],
                            );
                          }
                          return PageView(
                            children: [
                              // 封面页支持下滑手势关闭（仅移动端）
                              _SwipeDismiss(
                                child: _ArtworkView(song: song),
                              ),
                              const _LyricView(),
                            ],
                          );
                        },
                      ),
                    ),
                    _buildErrorHint(player),
                    _buildTitleRow(context, player, song),
                    _buildProgress(player),
                    _buildControls(context, player),
                    // 桌面端不显示音量控制
                    if (!_isDesktop) _VolumeRow(player: player),
                    const SizedBox(height: 8),
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

  /// Apple Music 风格：歌名/歌手左对齐，右边「...」更多
  Widget _buildTitleRow(
      BuildContext context, PlayerService player, Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artistNames,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            onPressed: () => _showMoreSheet(context, player, song),
          ),
        ],
      ),
    );
  }

  /// 「...」更多操作
  void _showMoreSheet(
      BuildContext context, PlayerService player, Song song) {
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
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('喜欢'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleLike(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.comment_outlined),
              title: const Text('评论'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/comments', arguments: song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('歌曲信息'),
              onTap: () {
                Navigator.pop(ctx);
                _showSongInfo(context, player, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.high_quality_outlined),
              title: Text('音质：${player.qualityLabel}'),
              onTap: () {
                Navigator.pop(ctx);
                _showQualitySheet(context, player);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('下一首播放'),
              onTap: () {
                Navigator.pop(ctx);
                player.playNext(song);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _toggleLike(BuildContext context, Song song) async {
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
    try {
      // 简单切换：先查喜欢列表比较重，这里直接调用喜欢接口
      await context.read<MusicService>().like(song.id, true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('已添加到我喜欢的音乐'),
              duration: Duration(milliseconds: 800)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
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

  /// Apple Music 风格进度条：细滑杆，左已播 / 右剩余（负数）
  /// [waveform] 为 true 时显示波浪形进度条
  Widget _buildProgress(PlayerService player) {
    final waveform =
        context.select<SettingsService, bool>((s) => s.waveformProgress);
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final total = player.duration ?? Duration.zero;
        final remain = total - pos;
        final progress = total.inMilliseconds > 0
            ? pos.inMilliseconds.clamp(0, total.inMilliseconds) /
                total.inMilliseconds
            : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              if (waveform)
                _WaveformProgress(
                  progress: progress,
                  songId: player.current?.id ?? 0,
                  onSeek: (p) => player.seek(Duration(
                      milliseconds:
                          (p * total.inMilliseconds).toInt())),
                )
              else
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.white70,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(pos),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54)),
                    Text('-${_fmt(remain.isNegative ? Duration.zero : remain)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
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

  /// Apple Music 风格控制区：大按钮无底圈
  Widget _buildControls(BuildContext context, PlayerService player) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_modeIcon(player.mode),
                size: 24, color: Colors.white70),
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
            icon: const Icon(Icons.skip_previous,
                size: 44, color: Colors.white),
            onPressed: player.prev,
          ),
          IconButton(
            icon: Icon(
              player.playing ? Icons.pause : Icons.play_arrow,
              size: 58,
              color: Colors.white,
            ),
            onPressed: player.toggle,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, size: 44, color: Colors.white),
            onPressed: player.next,
          ),
          IconButton(
            icon: const Icon(Icons.queue_music,
                size: 24, color: Colors.white70),
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

  /// 歌曲信息面板
  void _showSongInfo(
      BuildContext context, PlayerService player, Song song) {
    final duration = player.duration;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('歌曲信息',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoverImage(url: song.picUrl, size: 72, radius: 12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(song.artistNames,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _infoRow('专辑', song.album?.name ?? '未知专辑'),
              _infoRow('时长', duration != null ? _fmt(duration) : '--:--'),
              _infoRow('音质', player.qualityLabel),
              _infoRow('歌曲 ID', '${song.id}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(PlayMode mode) => switch (mode) {
        PlayMode.sequence => Icons.arrow_forward,
        PlayMode.loop => Icons.repeat,
        PlayMode.single => Icons.repeat_one,
        PlayMode.shuffle => Icons.shuffle,
      };
}

/// 下滑手势关闭（仅移动端）：在封面上快速下滑或下滑超过阈值时关闭播放页
class _SwipeDismiss extends StatelessWidget {
  final Widget child;
  const _SwipeDismiss({required this.child});

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) return child;
    double dragDistance = 0;
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        // 只统计向下的拖动
        if (details.delta.dy > 0) dragDistance += details.delta.dy;
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // 快速下滑（速度 > 600）或下滑距离超过 120 时关闭
        if (velocity > 600 || dragDistance > 120) {
          Navigator.pop(context);
        }
        dragDistance = 0;
      },
      onVerticalDragCancel: () => dragDistance = 0,
      child: child,
    );
  }
}

/// Apple Music 风格方形大封面：圆角 + 阴影
class _ArtworkView extends StatelessWidget {
  final Song song;
  const _ArtworkView({required this.song});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CoverImage(
                  url: song.picUrl, size: double.infinity, radius: 0),
            ),
          ),
        ),
      ),
    );
  }
}

/// 音量条（仅移动端）：与系统音量同步
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
    // 监听系统音量变化（fetchInitialVolume 取初始值；音量键/控制中心变化时同步）
    try {
      VolumeController.instance.addListener((v) {
        if (mounted) setState(() => _volume = v.clamp(0.0, 1.0));
      }, fetchInitialVolume: true);
    } catch (_) {
      // 不支持的平台忽略
    }
  }

  @override
  void dispose() {
    try {
      VolumeController.instance.removeListener();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.volume_down, size: 18, color: Colors.white54),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white54,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
              ),
              child: Slider(
                value: _volume,
                onChanged: (v) {
                  setState(() => _volume = v);
                  // 直接设置系统音量
                  VolumeController.instance.setVolume(v);
                },
              ),
            ),
          ),
          const Icon(Icons.volume_up, size: 18, color: Colors.white54),
        ],
      ),
    );
  }
}

/// 波浪形进度条：根据歌曲 ID 生成固定的波形，点击/拖动跳转
class _WaveformProgress extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final int songId;
  final ValueChanged<double> onSeek;
  const _WaveformProgress({
    required this.progress,
    required this.songId,
    required this.onSeek,
  });

  /// 根据歌曲 ID 生成确定性波形高度（0.2 - 1.0）
  List<double> _heights(int count) {
    final heights = <double>[];
    var seed = songId;
    for (var i = 0; i < count; i++) {
      // 简单的 LCG 伪随机，保证同一首歌波形一致
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      heights.add(0.25 + 0.75 * ((seed % 100) / 100));
    }
    return heights;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final pos = d.localPosition.dx / box.size.width;
        onSeek(pos.clamp(0.0, 1.0));
      },
      onTapUp: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final pos = d.localPosition.dx / box.size.width;
        onSeek(pos.clamp(0.0, 1.0));
      },
      child: SizedBox(
        height: 48,
        child: CustomPaint(
          painter: _WaveformPainter(
            progress: progress.clamp(0.0, 1.0),
            heights: _heights(64),
            playedColor: cs.primary,
            unplayedColor: Colors.white24,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final List<double> heights;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.progress,
    required this.heights,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = heights.length;
    final barWidth = size.width / count;
    final playedCount = (progress * count).floor();

    for (var i = 0; i < count; i++) {
      final h = heights[i] * size.height;
      final x = i * barWidth + barWidth * 0.25;
      final w = barWidth * 0.5;
      final y = (size.height - h) / 2;
      final paint = Paint()
        ..color = i < playedCount ? playedColor : unplayedColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.playedColor != playedColor ||
      old.unplayedColor != unplayedColor;
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
          stream: player.positionStream,
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
                              ? Colors.white
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
