# 云音乐 · Flutter 网易云音乐客户端

基于 [Binaryify/NeteaseCloudMusicApi](https://gitlab.com/Binaryify/NeteaseCloudMusicApi) 文档开发的第三方网易云音乐客户端。

- API 地址：`https://netease-cloudmusic-api-rosy.vercel.app`
- API 文档：`https://netease-cloudmusic-api-rosy.vercel.app/docs#/`
- UI：深色主题 + 网易云红，Material 3

## 功能

- **发现**：轮播 Banner、推荐歌单、推荐新歌、排行榜、热门歌手、每日推荐 / 新歌速递入口
- **搜索**：热搜榜、搜索建议（防抖）、单曲 / 歌单 / 专辑 / 歌手分页结果
- **歌单**：详情、全部歌曲、播放全部、收藏 / 取消收藏（需登录）
- **歌手**：热门 50 首、专辑、简介；**专辑**：详情与播放
- **播放器**：全屏播放页（旋转黑胶 / 同步歌词 / 翻译歌词）、播放队列、4 种播放模式（顺序 / 列表循环 / 单曲循环 / 随机）、进度拖动、音质切换（标准 / 较高 / 极高 / 无损）
- **登录**：二维码扫码登录（推荐）、手机号登录；登录态 cookie 持久化
- **我的**：个人资料、等级 / 累计听歌、我喜欢的音乐、每日推荐歌曲、创建与收藏的歌单、退出登录
- **评论**：歌曲精彩评论 / 最新评论分页
- 无版权歌曲自动跳过并提示

## 打包发布（GitHub Actions）

编译全部在 GitHub Actions 上完成，本地不需要配各平台 SDK。

```bash
# 1. 在 GitHub 新建空仓库，把本项目 push 上去
git init && git add -A && git commit -m "init"
git remote add origin git@github.com:<你>/<仓库>.git
git push -u origin main

# 2. 打标签触发构建，Release 会自动创建并附上所有产物
git tag v1.0.0 && git push origin v1.0.0

# 也可以在 Actions 页手动点 workflow_dispatch 跑一次（产物在 Artifacts 里）
```

| 平台 | 产物 |
|---|---|
| Android | `app-arm64-v8a-release.apk` / `app-armeabi-v7a-release.apk` / `app-x86_64-release.apk`（自签 release） |
| iOS | `*.ipa`（未签名，需自签后安装） |
| macOS | `netease-music-*.dmg` |
| Linux | `*.deb` / `*.rpm` / `*.AppImage` / pacman `*.pkg.tar.zst` |
| Windows | `*-windows-x64.zip`（绿色版） |

说明：

- **Android 自签**：CI 默认每次临时生成 keystore 自签（固定变量：alias=`cmsplayer`，store/key 密码=`134679`）。注意临时生成的 keystore 每次都不同，APK 无法覆盖安装升级；如需固定签名，把 keystore 转 base64 后存到仓库 Secrets：
  `ANDROID_KEYSTORE_BASE64`，以及 `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD` / `ANDROID_KEY_ALIAS`（对应值：`134679` / `134679` / `cmsplayer`）。
- **iOS IPA 未签名**：GitHub 无法做苹果官方签名，产物需用 AltStore / TrollStore / 自签工具安装到设备。
- Linux 包通过 [nfpm](https://github.com/goreleaser/nfpm) 打 deb/rpm/pacman，AppImage 用 appimagetool，配置在 `packaging/linux/`。
- workflow 文件：`.github/workflows/release.yml`，Flutter 版本 pin 在 `env.FLUTTER_VERSION`。

## 本地开发

需要 Flutter SDK（3.35+，已用 3.47.7 验证）。

```bash
cd netease_music
flutter pub get

# Web 运行 / 构建
flutter run -d chrome
flutter build web

# 桌面 / 移动端（需对应平台 SDK）
flutter build linux      # 需 clang/cmake/ninja/libgtk-3-dev
flutter build macos
flutter build windows
flutter build apk --release --split-per-abi
flutter build ipa --release --no-codesign
```

## 说明与限制

1. **播放需要登录**：未登录时 `/song/url` 普遍返回空链接。登录后（扫码即可）大部分免费歌曲可播；VIP / 付费歌曲需要对应会员，App 会自动跳过并提示。
2. **登录安全**：手机号登录密码经 MD5 后传输；cookie 只保存在本机 SharedPreferences，不上传任何第三方。
3. **Web 端图片**：API 返回的 `http://` 图片链接已统一转为 `https`，避免 Mixed Content 被浏览器拦截。
4. 登录态通过 query 参数 `cookie` 传递（浏览器禁止 JS 设置 Cookie 请求头，API 代理支持该方式）。
5. 本项目仅供学习交流，请勿用于商业用途，注意网易云音乐版权与 API 使用条款。

## 目录结构

```
lib/
  main.dart                 入口、路由、底部导航
  core/
    api.dart                Dio 封装（baseUrl / cookie / 时间戳防缓存）
    theme.dart              深色主题
    utils.dart              格式化工具
  models/models.dart        Song / Playlist / Artist / Lyric 等数据模型
  services/
    music_service.dart      全部 API 接口封装
    auth_service.dart       二维码 / 手机号登录与状态管理
    player_service.dart     just_audio 播放器：队列 / 模式 / 歌词 / 音质
  screens/                  发现 / 搜索 / 歌单 / 歌手 / 专辑 / 播放器 /
                            登录 / 我的 / 评论 / 榜单 / 通用歌曲列表
  widgets/                  迷你播放器 / 歌曲行 / 封面图 / 歌单卡片 / 区块标题
.github/workflows/
  release.yml               多平台构建 + Release 发布
packaging/linux/
  nfpm.yaml                 deb / rpm / pacman 打包配置
  netease-music.desktop     桌面入口
  icon.png                  应用图标
```
