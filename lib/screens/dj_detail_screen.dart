import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';

/// 播客电台详情：电台信息 + 节目列表，点击节目即播放
class DjDetailScreen extends StatefulWidget {
  final int radioId;
  const DjDetailScreen({super.key, required this.radioId});

  @override
  State<DjDetailScreen> createState() => _DjDetailScreenState();
}

class _DjDetailScreenState extends State<DjDetailScreen> {
  Future<DjRadio?>? _radioFuture;
  Future<List<DjProgram>>? _programsFuture;

  @override
  void initState() {
    super.initState();
    final music = context.read<MusicService>();
    _radioFuture = music.djDetail(widget.radioId);
    _programsFuture = music.djPrograms(widget.radioId, limit: 50);
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DjRadio?>(
      future: _radioFuture,
      builder: (context, snapshot) {
        final radio = snapshot.data;
        return Scaffold(
          body: FutureBuilder<List<DjProgram>>(
            future: _programsFuture,
            builder: (context, psnap) {
              final programs = psnap.data ?? [];
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(radio?.name ?? '播客电台',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15)),
                      background: radio == null
                          ? null
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                CoverImage(
                                    url: radio.picUrl,
                                    size: double.infinity,
                                    radius: 0),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.75),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (radio != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          radio.desc,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  if (psnap.connectionState == ConnectionState.waiting)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child: CircularProgressIndicator()),
                      ),
                    )
                  else if (psnap.hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                            child:
                                Text('加载失败：${psnap.error}')),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final p = programs[i];
                          return ListTile(
                            leading: CoverImage(
                                url: p.coverUrl, size: 52, radius: 8),
                            title: Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              '${_fmtMs(p.duration)} · 播放${p.listenerCount}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                            trailing: const Icon(
                                Icons.play_circle_outline,
                                color: AppColors.textSecondary),
                            onTap: () =>
                                _playProgram(context, programs, i),
                          );
                        },
                        childCount: programs.length,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _playProgram(
      BuildContext context, List<DjProgram> programs, int index) {
    final songs =
        programs.map((p) => p.toSong()).toList();
    context.read<PlayerService>().playQueue(songs, index);
  }
}
