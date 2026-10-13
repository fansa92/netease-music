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
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/player'),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      CoverImage(url: song.picUrl, size: 42, radius: 6),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
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
                      IconButton(
                        icon: Icon(
                          player.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 36,
                          color: Colors.white,
                        ),
                        onPressed: player.toggle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next,
                            color: Colors.white70),
                        onPressed: player.next,
                      ),
                      IconButton(
                        icon: const Icon(Icons.queue_music,
                            color: Colors.white70),
                        onPressed: () => _showQueue(context, player),
                      ),
                    ],
                  ),
                ),
                // 播放进度细条
                StreamBuilder<Duration>(
                  stream: player.player.positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final total =
                        player.player.duration ?? Duration.zero;
                    final ratio = total.inMilliseconds > 0
                        ? pos.inMilliseconds / total.inMilliseconds
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
                          ? const Icon(Icons.graphic_eq,
                              color: AppColors.primary, size: 20)
                          : null,
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? AppColors.primary : Colors.white,
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
