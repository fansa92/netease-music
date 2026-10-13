import '../core/api.dart';
import '../core/utils.dart';
import '../models/models.dart';

/// 网易云音乐 API 封装（基于 Binaryify/NeteaseCloudMusicApi）
class MusicService {
final ApiClient api;
MusicService(this.api);

// ---------- 发现 ----------

Future<List<BannerItem>> banners() async {
final d = await api.get('/banner', {'type': 1});
final list = d['banners'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(BannerItem.fromJson)
.toList();
}

Future<List<Playlist>> personalized({int limit = 12}) async {
final d = await api.get('/personalized', {'limit': limit});
final list = d['result'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(Playlist.fromJson)
.toList();
}

Future<List<Song>> newSongs({int limit = 12}) async {
final d = await api.get('/personalized/newsong', {'limit': limit});
final list = d['result'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(Song.fromJson)
.toList();
}

Future<List<Playlist>> toplists() async {
final d = await api.get('/toplist');
final list = d['list'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(Playlist.fromJson)
.toList();
}

Future<List<ArtistMini>> hotArtists({int limit = 12}) async {
final d = await api.get('/toplist/artist', {'type': 1});
final list = d['list'] as Map<String, dynamic>? ?? {};
final artists = list['artists'] as List? ?? [];
return artists
.whereType<Map<String, dynamic>>()
.take(limit)
.map(ArtistMini.fromJson)
.toList();
}

// ---------- 歌单 ----------

Future<Playlist> playlistDetail(int id) async {
final d = await api.get('/playlist/detail', {'id': id});
final p = d['playlist'] as Map<String, dynamic>?;
if (p == null) throw Exception('获取歌单详情失败');
return Playlist.fromDetail(p);
}

Future<List<Song>> playlistTracks(int id,
{int limit = 1000, int offset = 0}) async {
final d = await api
.get('/playlist/track/all', {'id': id, 'limit': limit, 'offset': offset});
final list = d['songs'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(Song.fromJson)
.toList();
}

/// 收藏 / 取消收藏歌单，t=1 收藏，t=2 取消
Future<void> playlistSubscribe(int id, bool subscribe) async {
final d = await api.get('/playlist/subscribe', {
'id': id,
't': subscribe? 1: 2,
});
if (intOf(d['code'])!= 200) throw Exception('操作失败');
}

// ---------- 搜索 ----------
// type: 1 单曲 10 专辑 100 艺人 1000 歌单

Future<SearchResult> search(String keywords, int type,
{int limit = 30, int offset = 0}) async {
final d = await api.get('/search', {
'keywords': keywords,
'type': type,
'limit': limit,
'offset': offset,
});
final r = d['result'] as Map<String, dynamic>? ?? {};

List<Song> songs = [];
List<Playlist> playlists = [];
List<ArtistMini> artists = [];
List<AlbumMini> albums = [];
final s = r['songs'];
if (s is List) {
songs = s.whereType<Map<String, dynamic>>().map(Song.fromJson).toList();
}
final pl = r['playlists'];
if (pl is List) {
playlists =
pl.whereType<Map<String, dynamic>>().map(Playlist.fromJson).toList();
}
final ar = r['artists'];
if (ar is List) {
artists =
ar.whereType<Map<String, dynamic>>().map(ArtistMini.fromJson).toList();
}
final ab = r['albums'];
if (ab is List) {
albums =
ab.whereType<Map<String, dynamic>>().map(AlbumMini.fromJson).toList();
}
return SearchResult(
songs: songs,
songCount: intOf(r['songCount']),
playlists: playlists,
playlistCount: intOf(r['playlistCount']),
artists: artists,
artistCount: intOf(r['artistCount']),
albums: albums,
albumCount: intOf(r['albumCount']),
hasMore: r['hasMore'] == true,
);
}

Future<List<HotWord>> searchHot() async {
final d = await api.get('/search/hot/detail');
final list = d['data'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(HotWord.fromJson)
.toList();
}

/// 搜索建议：返回各类命中的首批结果
Future<Map<String, List<dynamic>>> searchSuggest(String keywords) async {
final d = await api.get('/search/suggest', {
'keywords': keywords,
'type': 'mobile',
});
final r = d['result'] as Map<String, dynamic>? ?? {};
List<dynamic> mapList(String key, dynamic Function(Map<String, dynamic>) f) {
final l = r[key];
if (l is! List) return [];
return l.whereType<Map<String, dynamic>>().map(f).toList();
}

return {
'songs': mapList('songs', Song.fromJson),
'artists': mapList('artists', ArtistMini.fromJson),
'albums': mapList('albums', AlbumMini.fromJson),
'playlists': mapList('playlists', Playlist.fromJson),
};
}

// ---------- 歌曲 ----------

Future<List<Song>> songDetail(List<int> ids) async {
if (ids.isEmpty) return [];
final d = await api.get('/song/detail', {'ids': ids.join(',')});
final list = d['songs'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(Song.fromJson)
.toList();
}

/// 获取播放链接。未登录 / 无版权时返回 null。
Future<String?> songUrl(int id, {String level = 'standard'}) async {
final d = await api.get('/song/url/v1', {'id': id, 'level': level});
final list = d['data'] as List? ?? [];
if (list.isEmpty) return null;
final item = list.first;
if (item is! Map<String, dynamic>) return null;
final url = item['url'] as String?;
if (url == null || url.isEmpty) return null;
return httpsUrl(url);
}

/// 返回 (原文歌词, 翻译歌词)
Future<(List<LyricLine>, List<LyricLine>)> lyric(int id) async {
final d = await api.get('/lyric', {'id': id});
final lrc = (d['lrc'] as Map?)?['lyric'] as String?;
final tlyric = (d['tlyric'] as Map?)?['lyric'] as String?;
return (parseLyric(lrc), parseLyric(tlyric));
}

Future<CommentPage> comments(int id,
{int limit = 20, int offset = 0}) async {
final d = await api.get('/comment/music', {
'id': id,
'limit': limit,
'offset': offset,
});
List<CommentItem> mapComments(dynamic l) {
if (l is! List) return [];
return l.whereType<Map<String, dynamic>>().map(CommentItem.fromJson).toList();
}

return CommentPage(
hot: mapComments(d['hotComments']),
comments: mapComments(d['comments']),
total: intOf(d['total']),
hasMore: d['more'] == true,
);
}

Future<bool> checkMusic(int id) async {
final d = await api.get('/check/music', {'id': id});
return d['success'] == true;
}

// ---------- 歌手 / 专辑 ----------

Future<ArtistDetail> artist(int id) async {
final d = await api.get('/artists', {'id': id});
return ArtistDetail.fromJson(d);
}

Future<List<AlbumMini>> artistAlbums(int id, {int limit = 30}) async {
final d = await api.get('/artist/album', {'id': id, 'limit': limit});
final list = d['hotAlbums'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(AlbumMini.fromJson)
.toList();
}

Future<String> artistDesc(int id) async {
final d = await api.get('/artist/desc', {'id': id});
final buf = StringBuffer();
final brief = d['briefDesc'];
if (brief is String && brief.isNotEmpty) buf.writeln(brief);
final intro = d['introduction'];
if (intro is List) {
for (final e in intro) {
if (e is Map) {
final ti = e['ti'];
final txt = e['txt'];
if (ti is String && ti.isNotEmpty) buf.writeln('\n');
if (txt is String && txt.isNotEmpty) buf.writeln(txt);
}
}
}
final result = buf.toString().trim();
return result.isEmpty? '暂无介绍': result;
}

Future<(AlbumMini, List<Song>)> album(int id) async {
final d = await api.get('/album', {'id': id});
final a = d['album'];
if (a is! Map<String, dynamic>) throw Exception('获取专辑失败');
final songs = (d['songs'] as List? ?? [])
.whereType<Map<String, dynamic>>()
.map(Song.fromJson)
.toList();
return (AlbumMini.fromJson(a), songs);
}

// ---------- 用户（需登录） ----------

Future<List<Playlist>> userPlaylists(int uid, {int limit = 60}) async {
final d = await api.get('/user/playlist', {'uid': uid, 'limit': limit});
final list = d['playlist'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(Playlist.fromJson)
.toList();
}

Future<Map<String, dynamic>> userDetail(int uid) async {
return await api.get('/user/detail', {'uid': uid});
}

/// 喜欢的音乐 id 列表
Future<List<int>> likeList(int uid) async {
final d = await api.get('/likelist', {'uid': uid});
final list = d['ids'] as List? ?? [];
return list.map(intOf).toList();
}

Future<void> like(int id, bool like) async {
final d = await api.get('/like', {'id': id, 'like': like});
if (intOf(d['code'])!= 200) throw Exception('操作失败，请稍后重试');
}

Future<List<Song>> recommendSongs() async {
final d = await api.get('/recommend/songs');
final data = d['data'] as Map<String, dynamic>? ?? {};
final list = data['dailySongs'] as List? ?? [];
return list
.whereType<Map<String, dynamic>>()
.map(Song.fromJson)
.toList();
}
}
