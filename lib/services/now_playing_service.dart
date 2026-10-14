import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'player_service.dart';

/// iOS 锁屏 / 控制中心媒体信息同步。
/// 通过 MethodChannel 调用原生 NowPlayingPlugin 更新
/// MPNowPlayingInfoCenter，并接收远程控制回调。
///
/// 更新策略（无心跳、无节流）：
/// - 切歌时：全量更新（标题/歌手/专辑/封面/时长）
/// - 播放/暂停切换时：只更新播放状态（rate），进度由系统按 rate 自动推进
/// - 原生 seek 回调时：更新位置
/// iOS 会根据 MPNowPlayingInfoPropertyPlaybackRate 自动推进锁屏进度条，
/// 因此不需要定时轮询位置。
class NowPlayingService {
  static const _channel =
      MethodChannel('com.netease.music/nowplaying');

  /// 单例，供播放页打开时手动刷新
  static NowPlayingService? instance;

  final PlayerService player;
  StreamSubscription? _playingSub;
  int? _lastSongId;
  bool? _lastPlaying;

  NowPlayingService(this.player) {
    if (!Platform.isIOS) return;
    instance = this;
    _channel.setMethodCallHandler(_onNativeCall);
    player.addListener(_onPlayerChanged);
    _onPlayerChanged();
  }

  /// 公开刷新：切歌/播放页打开等关键时机调用
  Future<void> refresh() => _updateFull();

  void _onPlayerChanged() {
    final song = player.current;
    if (song == null) {
      // 防御：只有真正停止时才清，避免中间态误杀锁屏信息
      if (!player.playing) {
        _channel.invokeMethod('clear');
      }
      _lastSongId = null;
      _lastPlaying = null;
      return;
    }
    final songChanged = song.id != _lastSongId;
    final playingChanged = player.playing != _lastPlaying;
    if (songChanged) {
      _lastSongId = song.id;
      _lastPlaying = player.playing;
      _updateFull();
    } else if (playingChanged) {
      _lastPlaying = player.playing;
      _updatePlaybackState();
    }
  }

  /// 全量更新：切歌时调用
  Future<void> _updateFull() async {
    final song = player.current;
    if (song == null) return;
    for (var i = 0; i < 3; i++) {
      try {
        await _channel.invokeMethod('update', {
          'title': song.name,
          'artist': song.artistNames,
          'album': song.albumName,
          'artworkUrl': song.picUrl,
          'duration': player.duration?.inMilliseconds != null
              ? player.duration!.inMilliseconds / 1000.0
              : song.duration / 1000.0,
          'position': player.position.inMilliseconds / 1000.0,
          'isPlaying': player.playing,
        });
        return;
      } catch (_) {
        if (i < 2) await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
  }

  /// 只更新播放状态（播放/暂停），进度由系统按 rate 自动推进
  Future<void> _updatePlaybackState() async {
    try {
      await _channel.invokeMethod('updateState', {
        'isPlaying': player.playing,
        'position': player.position.inMilliseconds / 1000.0,
      });
    } catch (_) {}
  }

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPlay':
        if (!player.playing) await player.toggle();
        break;
      case 'onPause':
        if (player.playing) await player.toggle();
        break;
      case 'onToggle':
        await player.toggle();
        break;
      case 'onNext':
        await player.next();
        break;
      case 'onPrevious':
        await player.prev();
        break;
      case 'onSeek':
        final pos = (call.arguments as num?)?.toDouble() ?? 0;
        await player.seek(Duration(milliseconds: (pos * 1000).toInt()));
        // seek 后同步一次位置
        _updatePlaybackState();
        break;
    }
  }

  void dispose() {
    _playingSub?.cancel();
    player.removeListener(_onPlayerChanged);
  }
}
