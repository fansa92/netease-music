import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'player_service.dart';

/// iOS 锁屏 / 控制中心媒体信息同步。
/// 通过 MethodChannel 调用原生 NowPlayingPlugin 更新
/// MPNowPlayingInfoCenter，并接收远程控制回调。
class NowPlayingService {
  static const _channel =
      MethodChannel('com.netease.music/nowplaying');

  final PlayerService player;
  StreamSubscription? _posSub;
  Timer? _debounce;
  int? _lastSongId;

  NowPlayingService(this.player) {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler(_onNativeCall);
    player.addListener(_onPlayerChanged);
    // 进度变化时节流更新（锁屏进度条）
    _posSub = player.positionStream.listen((_) => _scheduleUpdate());
    _onPlayerChanged();
  }

  void _onPlayerChanged() {
    final song = player.current;
    if (song == null) {
      _channel.invokeMethod('clear');
      _lastSongId = null;
      return;
    }
    // 切歌立即更新，播放/暂停状态变化也更新
    if (song.id != _lastSongId) {
      _lastSongId = song.id;
      _update();
    } else {
      _scheduleUpdate();
    }
  }

  void _scheduleUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _update);
  }

  Future<void> _update() async {
    final song = player.current;
    if (song == null) return;
    // 重试 3 次，应对原生插件尚未就绪的情况
    for (var i = 0; i < 3; i++) {
      try {
        final pos = player.position;
        await _channel.invokeMethod('update', {
          'title': song.name,
          'artist': song.artistNames,
          'album': song.album?.name ?? '',
          'artworkUrl': song.picUrl,
          'duration': player.duration?.inMilliseconds != null
              ? player.duration!.inMilliseconds / 1000.0
              : 0.0,
          'position': pos.inMilliseconds / 1000.0,
          'isPlaying': player.playing,
        });
        return; // 成功则退出
      } catch (_) {
        if (i < 2) await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
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
        final secs = (call.arguments as num?)?.toDouble() ?? 0;
        await player.seek(Duration(milliseconds: (secs * 1000).toInt()));
        break;
    }
    // 远程操作后刷新一次状态
    _update();
  }

  void dispose() {
    _posSub?.cancel();
    _debounce?.cancel();
    player.removeListener(_onPlayerChanged);
  }
}
