import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/player_service.dart';
import 'cover_image.dart';

/// 通用歌曲行：序号 / 封面 / 歌名 / 歌手-专辑 / 时长 / 更多菜单
class SongTile extends StatelessWidget {
  final Song song;
  final int? index;
  final bool showPic;
  final bool showDuration;
  final VoidCallback? onTap;
  final bool highlight;

  const SongTile({
    super.key,
    required this.song,
    this.index,
    this.showPic = false,
    this.showDuration = true,
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = song.alias.isNotEmpty
        ? '${song.name}（${song.alias}）'
        : song.name;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: showPic
          ? CoverImage(url: song.picUrl, size: 44, radius: 12)
          : index != null
              ? SizedBox(
                  width: 28,
                  child: Text(
                    '$index',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: index! <= 3
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          index! <= 3 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                )
              : null,
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: highlight ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (song.isVip) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'VIP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${song.artistNames} - ${song.albumName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDuration)
            Text(
              formatDuration(song.duration),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert,
                size: 20, color: AppColors.textSecondary),
            onPressed: () => showSongActions(context, song),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 歌曲更多操作：下一首播放 / 查看评论 / 查看歌手 / 查看专辑
void showSongActions(BuildContext context, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final player = ctx.read<PlayerService>();
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CoverImage(url: song.picUrl, size: 44, radius: 12),
              title: Text(song.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(song.artistNames,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('下一首播放'),
              onTap: () {
                Navigator.pop(ctx);
                player.playNext(song);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已添加到下一首播放')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.comment_outlined),
              title: const Text('查看评论'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/comments',
                    arguments: song);
              },
            ),
            if (song.artists.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('歌手：${song.artists.first.name}'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/artist',
                      arguments: song.artists.first.id);
                },
              ),
            if (song.album != null && song.album!.id != 0)
              ListTile(
                leading: const Icon(Icons.album_outlined),
                title: Text('专辑：${song.albumName}'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/album',
                      arguments: song.album!.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
