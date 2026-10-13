import '../core/utils.dart';

class ArtistMini {
  final int id;
  final String name;
  final String picUrl;

  const ArtistMini({required this.id, required this.name, this.picUrl = ''});

  factory ArtistMini.fromJson(Map<String, dynamic> json) {
    return ArtistMini(
      id: intOf(json['id']),
      name: '${json['name'] ?? '未知艺人'}',
      picUrl: httpsUrl(json['picUrl'] as String? ??
          json['img1v1Url'] as String? ??
          json['pic'] as String?),
    );
  }
}

class AlbumMini {
  final int id;
  final String name;
  final String picUrl;
  final String artistNames;

  const AlbumMini({
    required this.id,
    required this.name,
    this.picUrl = '',
    this.artistNames = '',
  });

  factory AlbumMini.fromJson(Map<String, dynamic> json) {
    String artists = '';
    final ar = json['artists'];
    if (ar is List) {
      artists = ar
          .map((e) => '${(e as Map<String, dynamic>)['name'] ?? ''}')
          .where((s) => s.isNotEmpty)
          .join('/');
    } else if (json['artist'] is Map) {
      artists = '${(json['artist'] as Map)['name'] ?? ''}';
    }
    return AlbumMini(
      id: intOf(json['id']),
      name: '${json['name'] ?? '未知专辑'}',
      picUrl: httpsUrl(json['picUrl'] as String? ?? json['pic'] as String?),
      artistNames: artists,
    );
  }
}

class Song {
  final int id;
  final String name;
  final List<ArtistMini> artists;
  final AlbumMini? album;
  final int duration; // 毫秒
  final int fee; // 0 免费 / 1 VIP / 4 付费专辑等
  final int mvid;
  final String alias;

  const Song({
    required this.id,
    required this.name,
    this.artists = const [],
    this.album,
    this.duration = 0,
    this.fee = 0,
    this.mvid = 0,
    this.alias = '',
  });

  String get artistNames =>
      artists.isEmpty ? '未知艺人' : artists.map((a) => a.name).join('/');
  String get picUrl => album?.picUrl ?? '';
  String get albumName => album?.name ?? '';

  /// 兼容多种接口返回结构：
  /// - /playlist/track/all、/song/detail、/search、/artists：ar / al / dt
  /// - /personalized/newsong：外层 {id,name,picUrl} + 内层 song 对象
  factory Song.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> j = json;
    if (j['song'] is Map && j['ar'] == null && j['artists'] == null) {
      final nested = Map<String, dynamic>.from(j['song'] as Map);
      nested['id'] ??= json['id'];
      nested['name'] ??= json['name'];
      nested['picUrl'] ??= json['picUrl'];
      j = nested;
    }

    final artists = <ArtistMini>[];
    final ar = j['ar'] ?? j['artists'];
    if (ar is List) {
      for (final e in ar) {
        if (e is Map<String, dynamic>) artists.add(ArtistMini.fromJson(e));
      }
    }

    AlbumMini? album;
    final al = j['al'] ?? j['album'];
    if (al is Map<String, dynamic>) {
      album = AlbumMini.fromJson(al);
    } else {
      final pic = httpsUrl(j['picUrl'] as String?);
      if (pic.isNotEmpty) {
        album = AlbumMini(id: 0, name: '', picUrl: pic);
      }
    }

    String alias = '';
    final alia = j['alia'];
    if (alia is List && alia.isNotEmpty) alias = '${alia.first}';

    return Song(
      id: intOf(j['id']),
      name: '${j['name'] ?? '未知歌曲'}',
      artists: artists,
      album: album,
      duration: intOf(j['dt'] ?? j['duration']),
      fee: intOf(j['fee']),
      mvid: intOf(j['mv'] ?? j['mvid']),
      alias: alias,
    );
  }
}

class UserMini {
  final int userId;
  final String nickname;
  final String avatarUrl;
  final String signature;

  const UserMini({
    required this.userId,
    required this.nickname,
    this.avatarUrl = '',
    this.signature = '',
  });

  factory UserMini.fromJson(Map<String, dynamic> json) {
    return UserMini(
      userId: intOf(json['userId'] ?? json['id']),
      nickname: '${json['nickname'] ?? ''}',
      avatarUrl: httpsUrl(json['avatarUrl'] as String?),
      signature: '${json['signature'] ?? ''}',
    );
  }
}

class Playlist {
  final int id;
  final String name;
  final String coverUrl;
  final int playCount;
  final int trackCount;
  final String description;
  final List<String> tags;
  final UserMini? creator;
  final List<Song> tracks;
  final List<String> trackPreviews; // 排行榜 tracks: ["第一名 - 歌名", ...]

  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl = '',
    this.playCount = 0,
    this.trackCount = 0,
    this.description = '',
    this.tags = const [],
    this.creator,
    this.tracks = const [],
    this.trackPreviews = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    UserMini? creator;
    if (json['creator'] is Map<String, dynamic>) {
      creator =
          UserMini.fromJson(json['creator'] as Map<String, dynamic>);
    }
    final previews = <String>[];
    final tracks = json['tracks'];
    if (tracks is List) {
      for (final t in tracks) {
        if (t is Map<String, dynamic>) {
          final first = '${t['first'] ?? ''}';
          final second = '${t['second'] ?? ''}';
          if (first.isNotEmpty || second.isNotEmpty) {
            previews.add('$first - $second');
          }
        }
      }
    }
    return Playlist(
      id: intOf(json['id']),
      name: '${json['name'] ?? ''}',
      coverUrl: httpsUrl(json['picUrl'] as String? ??
          json['coverImgUrl'] as String? ??
          json['coverUrl'] as String?),
      playCount: intOf(json['playCount'] ?? json['playcount']),
      trackCount: intOf(json['trackCount']),
      description: '${json['description'] ?? json['copywriter'] ?? ''}',
      tags: (json['tags'] as List?)?.map((e) => '$e').toList() ?? [],
      creator: creator,
      trackPreviews: previews,
    );
  }

  /// /playlist/detail 返回结构
  factory Playlist.fromDetail(Map<String, dynamic> json) {
    final base = Playlist.fromJson(json);
    final tracks = <Song>[];
    final list = json['tracks'];
    if (list is List) {
      for (final e in list) {
        if (e is Map<String, dynamic>) tracks.add(Song.fromJson(e));
      }
    }
    return Playlist(
      id: base.id,
      name: base.name,
      coverUrl: base.coverUrl,
      playCount: base.playCount,
      trackCount: base.trackCount,
      description: base.description,
      tags: base.tags,
      creator: base.creator,
      tracks: tracks,
      trackPreviews: base.trackPreviews,
    );
  }
}

class BannerItem {
  final String pic;
  final int targetId;
  final int targetType; // 1 单曲 10 专辑 1000 歌单 1004 MV
  final String typeTitle;
  final String url;

  const BannerItem({
    required this.pic,
    this.targetId = 0,
    this.targetType = 0,
    this.typeTitle = '',
    this.url = '',
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      pic: httpsUrl(json['pic'] as String?),
      targetId: intOf(json['targetId']),
      targetType: intOf(json['targetType']),
      typeTitle: '${json['typeTitle'] ?? ''}',
      url: '${json['url'] ?? ''}',
    );
  }
}

class LyricLine {
  final int timeMs;
  final String text;

  const LyricLine({required this.timeMs, required this.text});
}

/// 解析 LRC 歌词
List<LyricLine> parseLyric(String? raw) {
  final lines = <LyricLine>[];
  if (raw == null || raw.isEmpty) return lines;
  final reg = RegExp(r'\[(\d{1,3}):(\d{2})[.:](\d{2,3})\]');
  for (final line in raw.split('\n')) {
    final m = reg.firstMatch(line);
    if (m == null) continue;
    final min = int.tryParse(m.group(1)!) ?? 0;
    final sec = int.tryParse(m.group(2)!) ?? 0;
    final fracStr = m.group(3)!;
    final frac = int.tryParse(fracStr) ?? 0;
    final ms = fracStr.length == 2 ? frac * 10 : frac;
    final text = line.substring(m.end).trim();
    if (text.isEmpty) continue;
    lines.add(LyricLine(timeMs: (min * 60 + sec) * 1000 + ms, text: text));
  }
  lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return lines;
}

class HotWord {
  final String searchWord;
  final int score;
  final String content;
  final String iconUrl;
  final int iconType;

  const HotWord({
    required this.searchWord,
    this.score = 0,
    this.content = '',
    this.iconUrl = '',
    this.iconType = 0,
  });

  factory HotWord.fromJson(Map<String, dynamic> json) {
    return HotWord(
      searchWord: '${json['searchWord'] ?? ''}',
      score: intOf(json['score']),
      content: '${json['content'] ?? ''}',
      iconUrl: httpsUrl(json['iconUrl'] as String?),
      iconType: intOf(json['iconType']),
    );
  }
}

class SearchResult {
  final List<Song> songs;
  final int songCount;
  final List<Playlist> playlists;
  final int playlistCount;
  final List<ArtistMini> artists;
  final int artistCount;
  final List<AlbumMini> albums;
  final int albumCount;
  final bool hasMore;

  const SearchResult({
    this.songs = const [],
    this.songCount = 0,
    this.playlists = const [],
    this.playlistCount = 0,
    this.artists = const [],
    this.artistCount = 0,
    this.albums = const [],
    this.albumCount = 0,
    this.hasMore = false,
  });
}

class CommentItem {
  final int commentId;
  final String content;
  final int time;
  final String timeStr;
  final int likedCount;
  final UserMini user;
  final List<CommentItem> beReplied;

  const CommentItem({
    required this.commentId,
    required this.content,
    this.time = 0,
    this.timeStr = '',
    this.likedCount = 0,
    required this.user,
    this.beReplied = const [],
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    final replied = <CommentItem>[];
    final br = json['beReplied'];
    if (br is List) {
      for (final e in br) {
        if (e is Map<String, dynamic>) {
          replied.add(CommentItem(
            commentId: 0,
            content: '${e['content'] ?? ''}',
            user: e['user'] is Map<String, dynamic>
                ? UserMini.fromJson(e['user'] as Map<String, dynamic>)
                : const UserMini(userId: 0, nickname: ''),
          ));
        }
      }
    }
    return CommentItem(
      commentId: intOf(json['commentId']),
      content: '${json['content'] ?? ''}',
      time: intOf(json['time']),
      timeStr: '${json['timeStr'] ?? ''}',
      likedCount: intOf(json['likedCount']),
      user: json['user'] is Map<String, dynamic>
          ? UserMini.fromJson(json['user'] as Map<String, dynamic>)
          : const UserMini(userId: 0, nickname: ''),
      beReplied: replied,
    );
  }
}

class CommentPage {
  final List<CommentItem> hot;
  final List<CommentItem> comments;
  final int total;
  final bool hasMore;

  const CommentPage({
    this.hot = const [],
    this.comments = const [],
    this.total = 0,
    this.hasMore = false,
  });
}

class ArtistDetail {
  final int id;
  final String name;
  final String picUrl;
  final String briefDesc;
  final int musicSize;
  final int albumSize;
  final int mvSize;
  final List<Song> hotSongs;

  const ArtistDetail({
    required this.id,
    required this.name,
    this.picUrl = '',
    this.briefDesc = '',
    this.musicSize = 0,
    this.albumSize = 0,
    this.mvSize = 0,
    this.hotSongs = const [],
  });

  factory ArtistDetail.fromJson(Map<String, dynamic> json) {
    final a = json['artist'] as Map<String, dynamic>? ?? {};
    final hotSongs = <Song>[];
    final hs = json['hotSongs'];
    if (hs is List) {
      for (final e in hs) {
        if (e is Map<String, dynamic>) hotSongs.add(Song.fromJson(e));
      }
    }
    return ArtistDetail(
      id: intOf(a['id'] ?? json['id']),
      name: '${a['name'] ?? ''}',
      picUrl: httpsUrl(a['picUrl'] as String? ?? a['img1v1Url'] as String?),
      briefDesc: '${a['briefDesc'] ?? ''}',
      musicSize: intOf(a['musicSize']),
      albumSize: intOf(a['albumSize']),
      mvSize: intOf(a['mvSize']),
      hotSongs: hotSongs,
    );
  }
}
