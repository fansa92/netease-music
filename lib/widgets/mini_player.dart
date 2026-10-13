import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/player_service.dart';
import 'cover_image.dart';

/// 底部迷你播放器：有播放队列时显示
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        final song = player.current;
        if (song == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/player'),
          child: Padding(
            // 悬浮卡片：参考 Border-Player 底部迷你播放栏
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Material(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              elevation: 6,
              shadowColor: Colors.black54,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 64,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          CoverImage(url: song.picUrl, size: 48, radius: 12),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artistNames,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 圆形填充播放键（Border-Player 风格）
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Material(
                              color: Theme.of(context).colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: player.toggle,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    player.playing
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 24,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.skip_next,
                                color: cs.onSurfaceVariant),
                            onPressed: player.next,
                          ),
                          IconButton(
                            icon: Icon(Icons.queue_music,
                                color: cs.onSurfaceVariant),
                            onPressed: () => _showQueue(context, player),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    // 播放进度细条
                    StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? Duration.zero;
                        final total =
                            player.duration ?? Duration.zero;
                        final ratio = total.inMilliseconds > 0
                            ? pos.inMilliseconds /
                                total.inMilliseconds
                            : 0.0;
                        return LinearProgressIndicator(
                          value: ratio.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context, PlayerService player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const QueueSheet(),
    );
  }
}

/// 播放列队列表
class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, player, _) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      '播放队列（${player.queue.length}）',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(player.modeLabel,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        player.clearQueue();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: player.queue.length,
                  itemBuilder: (context, i) {
                    final s = player.queue[i];
                    final isCurrent = i == player.index;
                    return ListTile(
                      dense: true,
                      leading: isCurrent
                          ? Icon(Icons.graphic_eq,
                              color: Theme.of(context).colorScheme.primary, size: 20)
                          : null,
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        s.artistNames,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppColors.textSecondary),
                        onPressed: () => player.removeAt(i),
                      ),
                      onTap: () {
                        player.jumpTo(i);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
