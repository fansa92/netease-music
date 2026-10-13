import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../services/music_service.dart';
import '../widgets/cover_image.dart';

/// 播客：推荐电台 / 热门电台
class DjScreen extends StatefulWidget {
  const DjScreen({super.key});

  @override
  State<DjScreen> createState() => _DjScreenState();
}

class _DjScreenState extends State<DjScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播客'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: '推荐'), Tab(text: '热门')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _DjRadioList(
              loader: (music) => music.djRecommend(limit: 30)),
          _DjRadioList(
              loader: (music) =>
                  music.djHot(limit: 30)),
        ],
      ),
    );
  }
}

class _DjRadioList extends StatefulWidget {
  final Future<List<DjRadio>> Function(MusicService) loader;
  const _DjRadioList({required this.loader});

  @override
  State<_DjRadioList> createState() => _DjRadioListState();
}

class _DjRadioListState extends State<_DjRadioList> {
  Future<List<DjRadio>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(context.read<MusicService>());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DjRadio>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败：${snapshot.error}'));
        }
        final radios = snapshot.data ?? [];
        if (radios.isEmpty) return const Center(child: Text('暂无内容'));
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = widget.loader(context.read<MusicService>());
            });
            await _future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: radios.length,
            separatorBuilder: (_, _) => const Divider(indent: 72),
            itemBuilder: (context, i) {
              final r = radios[i];
              return ListTile(
                leading: CoverImage(url: r.picUrl, size: 52, radius: 8),
                title: Text(r.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  r.desc.isNotEmpty
                      ? r.desc
                      : '${r.programCount}期节目',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
                onTap: () => Navigator.pushNamed(context, '/dj',
                    arguments: r.id),
              );
            },
          ),
        );
      },
    );
  }
}
