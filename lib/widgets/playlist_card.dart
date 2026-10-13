import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/models.dart';
import 'cover_image.dart';

/// 歌单卡片：封面 + 播放量角标 + 歌单名
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final double width;

  const PlaylistCard({super.key, required this.playlist, this.width = 120});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/playlist',
          arguments: playlist.id),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverImage(
                    url: playlist.coverUrl, size: width, radius: 10),
                Positioned(
                  right: 6,
                  top: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow,
                          size: 14, color: Colors.white),
                      Text(
                        formatPlayCount(playlist.playCount),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
