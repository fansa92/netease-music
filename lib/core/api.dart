import 'package:dio/dio.dart';

/// 统一的 API 客户端。
///
/// 说明：
/// 1. 登录态通过 query 参数 `cookie` 传递 —— 浏览器环境禁止 JS 手动设置 Cookie 请求头，
///    而网易云 API 代理支持直接传 cookie 参数；
/// 2. 每次请求自动带上 `timestamp`，避免命中服务端 2 分钟缓存。
class ApiClient {
  static const String baseUrl =
      'https://netease-cloudmusic-api-rosy.vercel.app';

  final Dio dio;
  String? cookie;

  ApiClient()
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
        ));

  Future<Map<String, dynamic>> get(String path,
      [Map<String, dynamic>? params]) async {
    final query = <String, dynamic>{
      ...?params,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    if (cookie != null && cookie!.isNotEmpty) {
      query['cookie'] = cookie;
    }
    final resp = await dio.get(path, queryParameters: query);
    return _asMap(resp.data);
  }

  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? params]) async {
    final query = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    if (cookie != null && cookie!.isNotEmpty) {
      query['cookie'] = cookie;
    }
    final resp = await dio.post(path, queryParameters: query, data: params);
    return _asMap(resp.data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'_raw': data};
  }
}
