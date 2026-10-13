import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/detail_scaffold.dart';
import 'dj_comments_screen.dart';
import 'dj_comments_screen.dart';

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
  bool _subed = false;
  bool _subLoading = false;

  @override
  void initState() {
    super.initState();
    final music = context.read<MusicService>();
    _radioFuture = music.djDetail(widget.radioId).then((r) {
      if (r != null && mounted) setState(() => _subed = r.subed);
      return r;
    });
    _programsFuture = music.djPrograms(widget.radioId, limit: 50);
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleSub(DjRadio radio) async {
    if (_subLoading) return;
    setState(() => _subLoading = true);
    final target = !_subed;
    try {
      await context.read<MusicService>().djSub(radio.id, target);
      if (!mounted) return;
      setState(() {
        _subed = target;
        _subLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(target ? '已收藏' : '已取消收藏')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DetailScaffold(
      child: FutureBuilder<DjRadio?>(
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
                                          Colors.black
                                              .withValues(alpha: 0.75),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (radio != null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            radio.desc,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: radio.djName.isEmpty
                                      ? null
                                      : () => Navigator.pushNamed(
                                            context,
                                            '/search',
                                            arguments: {
                                              'query': radio.djName
                                            },
                                          ),
                                  icon: radio.djAvatar.isNotEmpty
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                              radio.djAvatar),
                                          radius: 10,
                                        )
                                      : const Icon(Icons.person_outline,
                                          size: 18),
                                  label: Text(
                                    radio.djName.isEmpty
                                        ? '作者'
                                        : radio.djName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _subLoading
                                      ? null
                                      : () => _toggleSub(radio),
                                  icon: Icon(
                                    _subed
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: _subed ? Colors.red : null,
                                  ),
                                  label:
                                      Text(_subed ? '已收藏' : '收藏'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DjCommentsScreen(
                                          radio: radio),
                                    ),
                                  ),
                                  icon: const Icon(
                                      Icons.comment_outlined,
                                      size: 18),
                                  label: Text(
                                    radio.commentCount > 0
                                        ? '评论${radio.commentCount}'
                                        : '评论',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (psnap.connectionState ==
                        ConnectionState.waiting)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                              child:
                                  CircularProgressIndicator()),
                        ),
                      )
                    else if (psnap.hasError)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                              child: Text(
                                  '加载失败：${psnap.error}')),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final p = programs[i];
                            return ListTile(
                              leading: CoverImage(
                                  url: p.coverUrl,
                                  size: 52,
                                  radius: 8),
                              title: Text(p.name,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14)),
                              subtitle: Text(
                                '${_fmtMs(p.duration)} · 播放${p.listenerCount}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme
                                        .onSurfaceVariant),
                              ),
                              trailing: Icon(
                                  Icons.play_circle_outline,
                                  color: theme.colorScheme
                                      .onSurfaceVariant),
                              onTap: () => _playProgram(
                                  context, programs, i),
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
      ),
    );
  }

  void _playProgram(
      BuildContext context, List<DjProgram> programs, int index) {
    final songs = programs.map((p) => p.toSong()).toList();
    context.read<PlayerService>().playQueue(songs, index);
  }
}
