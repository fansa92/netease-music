import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'screens/album_detail_screen.dart';
import 'screens/artist_detail_screen.dart';
import 'screens/comments_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/player_screen.dart';
import 'screens/playlist_detail_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/song_list_screen.dart';
import 'screens/toplist_screen.dart';
import 'screens/user_screen.dart';
import 'services/auth_service.dart';
import 'services/music_service.dart';
import 'services/player_service.dart';
import 'services/settings_service.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient();
  final music = MusicService(api);
  final auth = AuthService(api);
  final player = PlayerService(music);
  final settings = SettingsService(api);
  await settings.init();
  await auth.init();

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
    // M3 动态取色：SettingsService 在 Android 12+ 上从系统壁纸取色，
    // 不可用或关闭时 buildTheme 用默认网易云红配色
    final settings = context.watch<SettingsService>();
    return MaterialApp(
      title: '云音乐',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(dynamicScheme: settings.effectiveScheme),
      home: const AppShell(),
      onGenerateRoute: (settings) {
        final args = settings.arguments;
        switch (settings.name) {
          case '/search':
            return MaterialPageRoute(
              builder: (_) =>
                  SearchScreen(autofocus: args is bool ? args : false),
            );
          case '/playlist':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(playlistId: args),
              );
            }
          case '/artist':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => ArtistDetailScreen(artistId: args),
              );
            }
          case '/artists':
            return MaterialPageRoute(builder: (_) => const ArtistsScreen());
          case '/album':
            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(albumId: args),
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
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case '/comments':
            if (args is Song) {
              return MaterialPageRoute(
                builder: (_) => CommentsScreen(song: args),
              );
            }
          case '/toplist':
            return MaterialPageRoute(builder: (_) => const ToplistScreen());
          case '/songlist':
            if (args is Map) {
              return MaterialPageRoute(
                builder: (_) => SongListScreen(
                  title: '${args['title'] ?? '歌曲列表'}',
                  loader: '${args['loader'] ?? ''}',
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

  final _tabs = const [HomeScreen(), SearchScreen(), UserScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _tabIndex, children: _tabs),
          ),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '发现',
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
  }
}
