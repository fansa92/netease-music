import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'screens/album_detail_screen.dart';
import 'screens/artist_detail_screen.dart';
import 'screens/comments_screen.dart';
import 'screens/dj_detail_screen.dart';
import 'screens/dj_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/player_screen.dart';
import 'screens/playlist_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/song_list_screen.dart';
import 'screens/theme_screen.dart';
import 'screens/toplist_screen.dart';
import 'screens/user_screen.dart';
import 'services/auth_service.dart';
import 'services/music_service.dart';
import 'services/player_service.dart';
import 'services/settings_service.dart';
import 'widgets/detail_scaffold.dart';
import 'widgets/mini_player.dart';

import 'services/now_playing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final music = MusicService(api);
  final auth = AuthService(api);
  final player = PlayerService(music);
  final settings = SettingsService(api);
  await settings.init();
  await auth.init();
  // iOS 锁屏/控制中心媒体信息同步（内部判断平台；持有引用防止被回收）
  final nowPlaying = NowPlayingService(player);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<MusicService>.value(value: music),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<PlayerService>.value(value: player),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
      ],
      child: const NeteaseMusicApp(),
    ),
  );
}

class NeteaseMusicApp extends StatelessWidget {
  const NeteaseMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // M3 主题：主题模式（跟随系统/浅色/深色）+ 动态取色/种子色 + 纯黑模式
    final settings = context.watch<SettingsService>();
    final seedColor = settings.effectiveSeedColor;
    return MaterialApp(
      title: '云音乐',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(brightness: Brightness.light, seedColor: seedColor),
      darkTheme: buildTheme(
        brightness: Brightness.dark,
        seedColor: seedColor,
        pureBlack: settings.pureBlack,
      ),
      home: const AppShell(),
      onGenerateRoute: (settings) {
        final args = settings.arguments;
        switch (settings.name) {
          case '/search':
            return MaterialPageRoute(
              builder: (_) => DetailScaffold(
                child: SearchScreen(autofocus: args is bool ? args : false),
              ),
            );
          case '/playlist':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => DetailScaffold(
                child: PlaylistDetailScreen(playlistId: args),
              ),
              );
            }
          case '/artist':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => DetailScaffold(
                child: ArtistDetailScreen(artistId: args),
              ),
              );
            }
          case '/artists':
            return MaterialPageRoute(builder: (_) => const DetailScaffold(child: ArtistsScreen()));
          case '/album':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => DetailScaffold(
                child: AlbumDetailScreen(albumId: args),
              ),
              );
            }
          case '/player':
            return MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const PlayerScreen(),
            );
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const DetailScaffold(child: SettingsScreen()));
          case '/theme':
            return MaterialPageRoute(builder: (_) => const DetailScaffold(child: ThemeScreen()));
          case '/dj':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => DetailScaffold(
                  child: DjDetailScreen(radioId: args),
                ),
              );
            }
          case '/comments':
            if (args is Song) {
              return MaterialPageRoute(
                builder: (_) => DetailScaffold(child: CommentsScreen(song: args)),
              );
            }
          case '/toplist':
            return MaterialPageRoute(builder: (_) => const DetailScaffold(child: ToplistScreen()));
          case '/songlist':
            if (args is Map) {
              return MaterialPageRoute(
                builder: (_) => DetailScaffold(
                  child: SongListScreen(
                    title: '${args['title'] ?? '歌曲列表'}',
                    loader: '${args['loader'] ?? ''}',
                  ),
                ),
              );
            }
        }
        return null;
      },
    );
  }
}

/// 底部导航：发现 / 搜索 / 我的 + 迷你播放器
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;

  final _tabs = const [HomeScreen(), DjScreen(), SearchScreen(), UserScreen()];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端（宽屏）：左侧栏，参考 Border-Player；移动端：底部导航
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _tabIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('发现'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.podcasts_outlined),
                      selectedIcon: Icon(Icons.podcasts),
                      label: Text('播客'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search),
                      label: Text('搜索'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('我的'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: IndexedStack(
                            index: _tabIndex, children: _tabs),
                      ),
                      const MiniPlayer(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                    index: _tabIndex, children: _tabs),
              ),
              const MiniPlayer(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) =>
                setState(() => _tabIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: '发现',
              ),
              NavigationDestination(
                icon: Icon(Icons.podcasts_outlined),
                selectedIcon: Icon(Icons.podcasts),
                label: '播客',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: '搜索',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        );
      },
    );
  }
}
