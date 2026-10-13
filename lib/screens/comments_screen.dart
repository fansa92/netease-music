import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/music_service.dart';
import '../widgets/cover_image.dart';

/// 歌曲评论
class CommentsScreen extends StatefulWidget {
  final Song song;
  const CommentsScreen({super.key, required this.song});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final List<CommentItem> _hot = [];
  final List<CommentItem> _comments = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  int _total = 0;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await context.read<MusicService>().comments(
            widget.song.id,
            limit: 20,
            offset: _comments.length,
          );
      if (!mounted) return;
      setState(() {
        if (_comments.isEmpty) _hot.addAll(page.hot);
        _comments.addAll(page.comments);
        _total = page.total;
        _hasMore = page.hasMore;
        _loading = false;
        _firstLoad = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _firstLoad = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('评论', style: TextStyle(fontSize: 16)),
            if (_total > 0)
              Text('共$_total条',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal)),
          ],
        ),
        centerTitle: true,
      ),
      body: _firstLoad && _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              itemCount:
                  _hot.length + _comments.length + 3, // 2 个标题 + 底部
              itemBuilder: (context, i) {
                int cursor = i;
                if (_hot.isNotEmpty) {
                  if (cursor == 0) {
                    return _header('精彩评论');
                  }
                  cursor--;
                  if (cursor < _hot.length) {
                    return _CommentTile(comment: _hot[cursor]);
                  }
                  cursor -= _hot.length;
                }
                if (cursor == 0) return _header('最新评论');
                cursor--;
                if (cursor < _comments.length) {
                  return _CommentTile(comment: _comments[cursor]);
                }
                // 底部
                return _loading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                            child: Text('没有更多了',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12))),
                      );
              },
            ),
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
              child: CoverImage(
                  url: comment.user.avatarUrl,
                  size: 36,
                  radius: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(comment.user.nickname,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          Text(
                            comment.timeStr.isNotEmpty
                                ? comment.timeStr
                                : '',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.thumb_up_outlined,
                        size: 14,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${comment.likedCount}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(comment.content,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5)),
                if (comment.beReplied.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '@${comment.beReplied.first.user.nickname}：${comment.beReplied.first.content}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
