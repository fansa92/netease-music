import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/models.dart';
import 'music_service.dart';

enum PlayMode { sequence, loop, single, shuffle }

const Map<String, String> qualityLevels = {
  'standard': '标准',
  'higher': '较高',
  'exhigh': '极高',
  'lossless': '无损',
};

/// 播放器：播放队列、播放模式、歌词同步、音质切换。
///
/// 不可播放的歌曲（无版权/需 VIP/链接失效）会自动跳过，
/// 一轮都播不了时给出提示而不是死循环。
class PlayerService extends ChangeNotifier {
  final MusicService music;
  final AudioPlayer player = AudioPlayer();
  final Random _random = Random();

  List<Song> queue = [];
  int index = -1;
  PlayMode mode = PlayMode.loop;

  List<LyricLine> lyrics = [];
  List<LyricLine> transLyrics = [];
  bool lyricLoading = false;

  String quality = 'standard';
  String? errorMessage;

  final Set<int> _failed = {};
  bool _busy = false;

  PlayerService(this.music) {
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onCompleted();
      }
      notifyListeners();
    });
    // 进度变化时刷新歌词高亮 / 进度条
    player.positionStream.listen((_) => notifyListeners());
  }

  Song? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;
  bool get hasQueue => queue.isNotEmpty;
  bool get playing => player.playing;
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
        player.stop();
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
    player.stop();
    notifyListeners();
  }

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
        try {
          url = await music.songUrl(song.id, level: quality);
        } catch (_) {
          url = null;
        }
        if (url != null && url.isNotEmpty) {
          try {
            await player.setUrl(url);
            await player.play();
            errorMessage = null;
            notifyListeners();
            return;
          } catch (_) {
            url = null;
          }
        }
        _failed.add(song.id);
        errorMessage = '《${song.name}》暂无播放版权，已跳过';
        notifyListeners();
        n = _nextIndex(n);
        attempts++;
      }
      errorMessage = '队列中没有可播放的歌曲（可能需要登录或 VIP）';
      notifyListeners();
    } finally {
      _busy = false;
    }
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
      await player.seek(Duration.zero);
      await player.play();
    } else {
      await next();
    }
  }

  // ---------- 播放控制 ----------

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      if (index < 0 && queue.isNotEmpty) {
        await _playAt(0);
      } else {
        await player.play();
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
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    await _playAt(_prevIndex(index));
  }

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> setVolume(double v) => player.setVolume(v.clamp(0.0, 1.0));

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
    final pos = player.position;
    await _playAt(index);
    // 尽量恢复到切换前的位置
    if (player.duration != null && pos < player.duration!) {
      await player.seek(pos);
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
    player.dispose();
    super.dispose();
  }
}
