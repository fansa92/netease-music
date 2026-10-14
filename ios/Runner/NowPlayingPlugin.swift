import Flutter
import UIKit
import MediaPlayer

/// 锁屏 / 控制中心媒体信息 + 远程控制（播放/暂停/上下曲/进度）
/// Dart 端通过 MethodChannel "com.netease.music/nowplaying" 调用 update/clear，
/// 原生端通过同一 channel 回调 onPlay/onPause/onNext/onPrevious/onSeek。
class NowPlayingPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var artworkTask: URLSessionDataTask?
  private var cachedArtworkUrl: String?
  private var cachedArtwork: MPMediaItemArtwork?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.netease.music/nowplaying",
      binaryMessenger: registrar.messenger()
    )
    let instance = NowPlayingPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.setupRemoteCommands()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "update":
      if let args = call.arguments as? [String: Any] {
        updateNowPlaying(args)
      }
      result(nil)
    case "clear":
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      result(nil)
    case "updateState":
      if let args = call.arguments as? [String: Any] {
        updatePlaybackState(args)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 只更新播放状态（rate）和位置，不碰元数据。
  /// iOS 会按 rate 自动推进锁屏进度条。
  private func updatePlaybackState(_ args: [String: Any]) {
    guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
      return
    }
    let isPlaying = (args["isPlaying"] as? Bool) ?? true
    if let position = args["position"] as? Double, position >= 0 {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
    }
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func updateNowPlaying(_ args: [String: Any]) {
    // 确保音频会话激活，否则锁屏不会显示（与 xyzfm 一致）
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
    } catch {
      // audioplayers 也会管理会话，失败时忽略
    }

    var info: [String: Any] = [:]
    if let title = args["title"] as? String, !title.isEmpty {
      info[MPMediaItemPropertyTitle] = title
    }
    if let artist = args["artist"] as? String, !artist.isEmpty {
      info[MPMediaItemPropertyArtist] = artist
    }
    if let album = args["album"] as? String, !album.isEmpty {
      info[MPMediaItemPropertyAlbumTitle] = album
    }
    if let duration = args["duration"] as? Double, duration > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = duration
    }
    if let position = args["position"] as? Double, position >= 0 {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
    }
    let isPlaying = (args["isPlaying"] as? Bool) ?? true
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

    // 封面：用缓存的（同 URL 不重复下载），一次写完避免竞态
    let artworkUrl = args["artworkUrl"] as? String ?? ""
    if !artworkUrl.isEmpty,
       artworkUrl == cachedArtworkUrl,
       let cached = cachedArtwork {
      info[MPMediaItemPropertyArtwork] = cached
    }

    // 防御：空信息不写，避免误清空锁屏
    if info.isEmpty { return }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info

    // 封面异步下载：URL 变化时才下载，下载完只更新封面
    if !artworkUrl.isEmpty, artworkUrl != cachedArtworkUrl,
       let url = URL(string: artworkUrl) {
      artworkTask?.cancel()
      let targetUrl = artworkUrl
      artworkTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
        guard let self = self,
              let data = data,
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async {
          // 只有当前歌曲还是这个 URL 时才更新，防止旧下载覆盖新歌
          let currentTitle = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String
          let newTitle = args["title"] as? String
          guard currentTitle == newTitle else { return }
          let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
          self.cachedArtworkUrl = targetUrl
          self.cachedArtwork = artwork
          var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
          updated[MPMediaItemPropertyArtwork] = artwork
          MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        }
      }
      artworkTask?.resume()
    }
  }

  private func setupRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("onPlay", arguments: nil)
      return .success
    }

    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("onPause", arguments: nil)
      return .success
    }

    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("onToggle", arguments: nil)
      return .success
    }

    center.nextTrackCommand.isEnabled = true
    center.nextTrackCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("onNext", arguments: nil)
      return .success
    }

    center.previousTrackCommand.isEnabled = true
    center.previousTrackCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("onPrevious", arguments: nil)
      return .success
    }

    center.changePlaybackPositionCommand.isEnabled = true
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      if let e = event as? MPChangePlaybackPositionCommandEvent {
        self?.channel?.invokeMethod("onSeek", arguments: e.positionTime)
      }
      return .success
    }
  }
}
