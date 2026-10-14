import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'music_service.dart';

enum PlayMode { sequence, loop, single, shuffle }

const Map<String, String> qualityLevels = {
  'standard': '标准',
  'higher': '较高',
  'exhigh': '极高',
  'lossless': '无损',
};

/// 网易云播放器：歌曲队列、播放模式、倍速、歌词同步、音质切换。
///
/// 底层逻辑采用 xyzfm 的播放器逻辑：
/// - 取不到 URL 的歌曲自动跳过，一轮都播不了时给出提示。
/// - 顺序播放到最后一首时停住（不循环）。
/// - 切歌/暂停时不再做云端进度上报（网易云无此接口）。
class PlayerService extends ChangeNotifier {
  final MusicService music;
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  List<Song> queue = [];
  int index = -1;
  PlayMode mode = PlayMode.loop;

  double _speed = 1.0;
  double get speed => _speed;

  List<LyricLine> lyrics = [];
  List<LyricLine> transLyrics = [];
  bool lyricLoading = false;

  String quality = 'standard';
  String? errorMessage;
  DateTime _lastErrorTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// 设置错误信息（3 秒内不覆盖，方便看清跳过原因）
  void _setError(String msg) {
    final now = DateTime.now();
    if (now.difference(_lastErrorTime).inSeconds >= 3 ||
        errorMessage == null) {
      errorMessage = msg;
      _lastErrorTime = now;
      notifyListeners();
    }
  }

  final Set<int> _failed = {};
  bool _busy = false;

  /// URL 缓存：预加载下一首，切歌时直接用
  final Map<int, String> _urlCache = {};

  PlayerService(this.music) {
    _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) => _onCompleted());
    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    _loadSpeed();
  }

  Future<void> _loadSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getDouble('play_speed') ?? 1.0;
      if (s >= 0.5 && s <= 3.0) {
        _speed = s;
        await _player.setPlaybackRate(s);
        notifyListeners();
      }
    } catch (_) {}
  }

  Song? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;
  bool get hasQueue => queue.isNotEmpty;
  bool get playing => _playing;
  Duration get position => _position;
  Duration? get duration => _duration;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<bool> get playingStream =>
      _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);
  String get qualityLabel => qualityLevels[quality] ?? '标准';

  String get modeLabel => switch (mode) {
        PlayMode.sequence => '顺序播放',
        PlayMode.loop => '列表循环',
        PlayMode.single => '单曲循环',
        PlayMode.shuffle => '随机播放',
      };

  // ---------- 队列控制 ----------

  Future<void> playQueue(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    queue = List.of(songs);
    _failed.clear();
    await _playAt(startIndex.clamp(0, queue.length - 1));
  }

  Future<void> jumpTo(int i) async {
    if (i < 0 || i >= queue.length) return;
    await _playAt(i);
  }

  /// 下一首播放：插到当前歌曲后面
  Future<void> playNext(Song song) async {
    if (queue.isEmpty) {
      await playQueue([song], 0);
      return;
    }
    queue.insert(index + 1, song);
    notifyListeners();
  }

  void removeAt(int i) {
    if (i < 0 || i >= queue.length) return;
    queue.removeAt(i);
    if (i == index) {
      if (queue.isEmpty) {
        index = -1;
        _player.stop();
      } else {
        _playAt(i % queue.length);
      }
    } else if (i < index) {
      index--;
    }
    notifyListeners();
  }

  void clearQueue() {
    queue = [];
    index = -1;
    _player.stop();
    notifyListeners();
  }

  // ---------- 播放实现 ----------

  Future<void> _playAt(int i) async {
    if (queue.isEmpty || _busy) return;
    _busy = true;
    errorMessage = null;
    try {
      int n = i;
      int attempts = 0;
      while (attempts < queue.length) {
        final song = queue[n];
        if (_failed.contains(song.id)) {
          n = _nextIndex(n);
          attempts++;
          continue;
        }
        index = n;
        lyrics = [];
        transLyrics = [];
        notifyListeners();
        _loadLyrics(song.id);

        String? url;
        String? urlError;
        // 优先用预加载的 URL
        if (_urlCache.containsKey(song.id)) {
          url = _urlCache.remove(song.id);
        } else {
          try {
            url = await music.songUrl(song.id, level: quality);
          } catch (e) {
            url = null;
            urlError = e.toString();
          }
        }
        if (url == null || url.isEmpty) {
          // 接口没返回播放链接：未登录 / 无版权 / 需 VIP / 网络异常
          _failed.add(song.id);
          final reason = urlError != null
              ? '获取链接异常[$quality]：$urlError'
              : '接口未返回播放链接[$quality]，可能无版权/需VIP/需登录';
          _setError('《${song.name}》已跳过：$reason');
          n = _nextIndex(n);
          attempts++;
          continue;
        }
        try {
          await _player.play(UrlSource(url));
          // 倍速在 play 成功后设置，失败不影响播放（单独 try）
          try {
            await _player.setPlaybackRate(_speed);
          } catch (_) {}
          errorMessage = null;
          notifyListeners();
          // 预加载下一首的 URL，切歌时更快
          _prefetchNext(n);
          return;
        } catch (e) {
          // 链接拿到了，但播放器加载失败：和"暂无版权"区分开
          _failed.add(song.id);
          _setError('《${song.name}》播放器加载失败：$e');
        }
        n = _nextIndex(n);
        attempts++;
      }
      _setError('队列中没有可播放的歌曲（可能需要登录或 VIP）');
    } finally {
      _busy = false;
    }
  }

  /// 后台预加载下一首的播放 URL（不阻塞当前播放）
  void _prefetchNext(int currentIndex) {
    if (queue.isEmpty) return;
    final nextIdx = _nextIndex(currentIndex);
    if (nextIdx == currentIndex) return;
    final song = queue[nextIdx];
    if (_failed.contains(song.id) || _urlCache.containsKey(song.id)) return;
    music.songUrl(song.id, level: quality).then((url) {
      if (url != null && url.isNotEmpty) {
        _urlCache[song.id] = url;
      }
    }).catchError((_) {});
  }

  int _nextIndex(int from) {
    if (queue.isEmpty) return 0;
    if (mode == PlayMode.shuffle) return _random.nextInt(queue.length);
    final n = from + 1;
    return n >= queue.length ? 0 : n;
  }

  int _prevIndex(int from) {
    if (queue.isEmpty) return 0;
    if (mode == PlayMode.shuffle) return _random.nextInt(queue.length);
    final n = from - 1;
    return n < 0 ? queue.length - 1 : n;
  }

  Future<void> _onCompleted() async {
    if (mode == PlayMode.single && current != null) {
      await _player.seek(Duration.zero);
      await _player.resume();
    } else if (mode == PlayMode.sequence &&
        index >= 0 &&
        index == queue.length - 1) {
      // 顺序播放到最后一首：停住（xyzfm 逻辑）
      await _player.stop();
    } else {
      await next();
    }
  }

  // ---------- 播放控制 ----------

  Future<void> toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      if (index < 0 && queue.isNotEmpty) {
        await _playAt(0);
      } else {
        await _player.resume();
      }
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    await _playAt(_nextIndex(index));
  }

  Future<void> prev() async {
    if (queue.isEmpty) return;
    // 播放超过 3 秒时回到开头，否则上一首
    if (_position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    await _playAt(_prevIndex(index));
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));

  /// 倍速 0.5x ~ 3.0x，持久化（xyzfm 逻辑）
  Future<void> setSpeed(double s) async {
    s = s.clamp(0.5, 3.0);
    _speed = s;
    await _player.setPlaybackRate(s);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('play_speed', s);
    } catch (_) {}
    notifyListeners();
  }

  void cycleMode() {
    mode = switch (mode) {
      PlayMode.sequence => PlayMode.loop,
      PlayMode.loop => PlayMode.single,
      PlayMode.single => PlayMode.shuffle,
      PlayMode.shuffle => PlayMode.sequence,
    };
    notifyListeners();
  }

  Future<void> setQuality(String level) async {
    if (quality == level || current == null) {
      quality = level;
      notifyListeners();
      return;
    }
    quality = level;
    _failed.remove(current!.id);
    final pos = _position;
    await _playAt(index);
    // 尽量恢复到切换前的位置
    if (_duration != null && pos < _duration!) {
      await _player.seek(pos);
    }
    notifyListeners();
  }

  // ---------- 歌词 ----------

  Future<void> _loadLyrics(int id) async {
    lyricLoading = true;
    try {
      final (lrc, trc) = await music.lyric(id);
      if (current?.id == id) {
        lyrics = lrc;
        transLyrics = trc;
      }
    } catch (_) {
      if (current?.id == id) {
        lyrics = [];
        transLyrics = [];
      }
    }
    lyricLoading = false;
    notifyListeners();
  }

  /// 给定播放位置，返回当前歌词行下标（-1 表示无）
  int lyricIndexAt(Duration position) {
    if (lyrics.isEmpty) return -1;
    final ms = position.inMilliseconds;
    int idx = -1;
    for (int k = 0; k < lyrics.length; k++) {
      if (lyrics[k].timeMs <= ms) {
        idx = k;
      } else {
        break;
      }
    }
    return idx;
  }

  String? transTextOf(int lyricIndex) {
    if (lyricIndex < 0 ||
        lyricIndex >= lyrics.length ||
        transLyrics.isEmpty) {
      return null;
    }
    // 用时间戳对齐翻译行
    final t = lyrics[lyricIndex].timeMs;
    for (final line in transLyrics) {
      if ((line.timeMs - t).abs() < 500) return line.text;
    }
    return null;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
