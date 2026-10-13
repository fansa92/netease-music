import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/music_service.dart';
import '../services/player_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';

enum _Stage { hot, suggest, result }

class SearchScreen extends StatefulWidget {
  final bool autofocus;
  const SearchScreen({super.key, this.autofocus = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  _Stage _stage = _Stage.hot;

  List<HotWord> _hotWords = [];
  bool _hotLoading = true;
  Map<String, List<dynamic>>? _suggest;
  String _submitted = '';

  late TabController _tabController;
  final _tabs = const ['单曲', '歌单', '专辑', '歌手', '播客'];
  final _types = const [1, 1000, 10, 100, 1009];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHot();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHot() async {
    try {
      final words = await context.read<MusicService>().searchHot();
      if (mounted) setState(() => _hotWords = words);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _hotLoading = false);
    }
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _stage = _Stage.hot;
        _suggest = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      try {
        final s =
            await context.read<MusicService>().searchSuggest(text.trim());
        if (!mounted) return;
        // 用户可能已经清空或提交，忽略过期结果
        if (_controller.text.trim() != text.trim()) return;
        setState(() {
          _suggest = s;
          _stage = _Stage.suggest;
        });
      } catch (_) {}
    });
  }

  void _submit(String keywords) {
    final kw = keywords.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = kw;
      _stage = _Stage.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: '搜索歌曲、歌手、歌单、专辑',
            prefixIcon: const Icon(Icons.search,
                color: AppColors.textSecondary, size: 20),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                      setState(() {});
                    },
                  )
                : null,
          ),
          onTap: () => setState(() {}), // 刷新 clear 按钮状态
        ),
        actions: [
          TextButton(
            onPressed: () => _submit(_controller.text),
            child: Text('搜索',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 15)),
          ),
        ],
      ),
      body: switch (_stage) {
        _Stage.hot => _buildHot(),
        _Stage.suggest => _buildSuggest(),
        _Stage.result => _buildResult(),
      },
    );
  }

  Widget _buildHot() {
    if (_hotLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('热搜榜',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ..._hotWords.asMap().entries.map((e) {
          final i = e.key;
          final w = e.value;
          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 28,
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: i < 3 ? Theme.of(context).colorScheme.primary : AppColors.textSecondary,
                ),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    w.searchWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                if (w.iconType == 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('🔥',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            subtitle: w.content.isNotEmpty
                ? Text(w.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12))
                : null,
            trailing: Text(
              '${w.score}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
            onTap: () {
              _controller.text = w.searchWord;
              _submit(w.searchWord);
            },
          );
        }),
      ],
    );
  }

  Widget _buildSuggest() {
    final s = _suggest;
    if (s == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final kw = _controller.text.trim();
    final songs = (s['songs'] as List).whereType<Song>().toList();
    final artists = (s['artists'] as List).whereType<ArtistMini>().toList();
    final albums = (s['albums'] as List).whereType<AlbumMini>().toList();
    final playlists =
        (s['playlists'] as List).whereType<Playlist>().toList();

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(t,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        );

    return ListView(
      children: [
        ListTile(
          leading: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
          title: Text('搜索：$kw',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          onTap: () => _submit(kw),
        ),
        const Divider(),
        if (songs.isNotEmpty) ...[
          sectionTitle('单曲'),
          ...songs.take(5).map((song) => ListTile(
                dense: true,
                leading: const Icon(Icons.music_note,
                    color: AppColors.textSecondary),
                title: Text(song.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(song.artistNames,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () =>
                    context.read<PlayerService>().playQueue([song], 0),
              )),
        ],
        if (artists.isNotEmpty) ...[
          sectionTitle('歌手'),
          ...artists.take(3).map((a) => ListTile(
                dense: true,
                leading: const Icon(Icons.person,
                    color: AppColors.textSecondary),
                title: Text(a.name),
                onTap: () => Navigator.pushNamed(context, '/artist',
                    arguments: a.id),
              )),
        ],
        if (albums.isNotEmpty) ...[
          sectionTitle('专辑'),
          ...albums.take(3).map((a) => ListTile(
                dense: true,
                leading: const Icon(Icons.album,
                    color: AppColors.textSecondary),
                title: Text(a.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(a.artistNames,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pushNamed(context, '/album',
                    arguments: a.id),
              )),
        ],
        if (playlists.isNotEmpty) ...[
          sectionTitle('歌单'),
          ...playlists.take(3).map((p) => ListTile(
                dense: true,
                leading: CoverImage(url: p.coverUrl, size: 40, radius: 6),
                title: Text(p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pushNamed(context, '/playlist',
                    arguments: p.id),
              )),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: Theme.of(context).colorScheme.primary,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(
              5,
              (i) => _ResultTab(
                key: ValueKey('$_submitted-$i'),
                keywords: _submitted,
                type: _types[i],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 搜索结果分页列表
class _ResultTab extends StatefulWidget {
  final String keywords;
  final int type;
  const _ResultTab(
      {super.key, required this.keywords, required this.type});

  @override
  State<_ResultTab> createState() => _ResultTabState();
}

class _ResultTabState extends State<_ResultTab> {
  final List<dynamic> _items = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  bool _error = false;
  int _total = 0;

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
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final music = context.read<MusicService>();
      final r = await music.search(widget.keywords, widget.type,
          limit: 30, offset: _items.length);
      if (!mounted) return;
      List<dynamic> page = [];
      switch (widget.type) {
        case 1:
          page = r.songs;
          _total = r.songCount;
        case 1000:
          page = r.playlists;
          _total = r.playlistCount;
        case 10:
          page = r.albums;
          _total = r.albumCount;
        case 100:
          page = r.artists;
          _total = r.artistCount;
        case 1009:
          page = r.djRadios;
          _total = r.djRadioCount;
      }
      setState(() {
        _items.addAll(page);
        _hasMore = r.hasMore && page.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error) {
      return Center(
        child: TextButton(onPressed: _loadMore, child: const Text('加载失败，点击重试')),
      );
    }
    if (_items.isEmpty) {
      return const Center(
          child: Text('没有找到相关结果',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return Column(
      children: [
        if (_total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('共 $_total 条结果',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _items.length + 1,
            itemBuilder: (context, i) {
              if (i == _items.length) {
                if (_error) {
                  return TextButton(
                      onPressed: _loadMore,
                      child: const Text('加载失败，点击重试'));
                }
                return _hasMore
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
              }
              return _buildItem(_items[i]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItem(dynamic item) {
    final player = context.read<PlayerService>();
    if (item is Song) {
      final songs = _items.whereType<Song>().toList();
      final idx = songs.indexOf(item);
      return SongTile(
        song: item,
        showPic: true,
        onTap: () => player.playQueue(songs, idx),
      );
    }
    if (item is Playlist) {
      return ListTile(
        leading: CoverImage(url: item.coverUrl, size: 52, radius: 8),
        title: Text(item.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${item.trackCount}首 · 播放${item.playCount}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        onTap: () => Navigator.pushNamed(context, '/playlist',
            arguments: item.id),
      );
    }
    if (item is AlbumMini) {
      return ListTile(
        leading: CoverImage(url: item.picUrl, size: 52, radius: 8),
        title: Text(item.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(item.artistNames,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        onTap: () =>
            Navigator.pushNamed(context, '/album', arguments: item.id),
      );
    }
    if (item is ArtistMini) {
      return ListTile(
        leading: ClipOval(
            child: CoverImage(url: item.picUrl, size: 52, radius: 26)),
        title: Text(item.name),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary),
        onTap: () =>
            Navigator.pushNamed(context, '/artist', arguments: item.id),
      );
    }
    if (item is DjRadio) {
      return ListTile(
        leading: CoverImage(url: item.picUrl, size: 52, radius: 8),
        title: Text(item.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            item.desc.isNotEmpty
                ? item.desc
                : '${item.programCount}期节目',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary),
        onTap: () =>
            Navigator.pushNamed(context, '/dj', arguments: item.id),
      );
    }
    return const SizedBox.shrink();
  }
}
