import 'package:http/http.dart' as http;
import '../models/ai_service.dart';

enum ReachabilityStatus { ok, restricted, unreachable }

/// 单个服务的可达性检测结果。
class ReachabilityResult {
  final AiService service;
  final ReachabilityStatus status;
  final int? statusCode;
  final String? detail;

  const ReachabilityResult({
    required this.service,
    required this.status,
    this.statusCode,
    this.detail,
  });
}

/// 服务可达性检测：设置页手动触发，逐个探测服务 URL 是否可访问。
class ReachabilityService {
  /// 按状态码归类：
  /// 2xx/3xx 正常；401/403/405/429/451 表示站点在线但拦截了探测请求
  /// （脚本/反爬策略），归为「受限」；其余视为无法访问。
  static ReachabilityStatus classifyStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 400) return ReachabilityStatus.ok;
    const restrictedCodes = {401, 403, 405, 429, 451};
    if (restrictedCodes.contains(statusCode)) {
      return ReachabilityStatus.restricted;
    }
    return ReachabilityStatus.unreachable;
  }

  /// 探测单个服务。用 GET（部分站点对 HEAD 返回 405），
  /// 拿到状态码后立即关闭连接，不下载响应体。
  Future<ReachabilityResult> check(
    AiService service, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final uri = Uri.tryParse(service.url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return ReachabilityResult(
        service: service,
        status: ReachabilityStatus.unreachable,
        detail: '无效链接',
      );
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await client.send(request).timeout(timeout);
      return ReachabilityResult(
        service: service,
        status: classifyStatus(response.statusCode),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ReachabilityResult(
        service: service,
        status: ReachabilityStatus.unreachable,
        detail: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  /// 并发探测所有服务。
  Future<List<ReachabilityResult>> checkAll(List<AiService> services) async {
    return Future.wait(services.map((s) => check(s)));
  }
}
