import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/public_ip_info.dart';

class PublicIpInfoService {
  PublicIpInfoService({required http.Client client}) : _client = client;

  static const int maxResponseBytes = 64 * 1024;
  static const Duration _responseCancellationTimeout =
      Duration(milliseconds: 50);

  /// This hostname publishes only IPv4 results. The clients support IPv6 for
  /// traffic and nodes, but the home page intentionally presents a stable IPv4
  /// public address.
  /// 所有 IPv4 查询源，并发请求取最快返回的（含国内可直连源）
  static final List<Uri> allIpv4Endpoints = [
    Uri.parse('https://api.ipify.org?format=json'),
    Uri.parse('https://api4.ipify.org/?format=json'),
    Uri.parse('https://api.ip.sb/geoip'),
    Uri.parse('https://api.myip.com'),
    Uri.parse('https://ipapi.co/json/'),
    Uri.parse('https://httpbin.org/ip'),
    Uri.parse('https://ifconfig.me/ip'),
    Uri.parse('https://cip.cc'),
    Uri.parse('https://myip.ipip.net'),
  ];

  static Uri geoEndpointForIp(String ip) =>
      Uri.https('api.ip.sb', '/geoip/$ip');

  final http.Client _client;

  Future<PublicIpInfo> fetch({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // 并发请求所有源，取最快成功的
    final completer = Completer<PublicIpInfo>();
    var remaining = allIpv4Endpoints.length;
    final errors = <Object>[];

    for (final endpoint in allIpv4Endpoints) {
      unawaited(() async {
        try {
          final response = await _get(endpoint, const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final ip = _parseIpOnly(response.body);
            if (_isIpv4(ip)) {
              if (!completer.isCompleted) {
                completer.complete(PublicIpInfo(ip: ip!, countryCode: ''));
              }
              return;
            }
            // 尝试解析带地理信息的
            try {
              final info = parse(response.body);
              if (_isIpv4(info.ip) && !completer.isCompleted) {
                completer.complete(info);
                return;
              }
            } catch (_) {}
          }
          throw 'HTTP ${response.statusCode}';
        } catch (e) {
          errors.add(e);
        } finally {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.completeError(
              PublicIpInfoException('所有 IP 查询源均失败'),
            );
          }
        }
      }());
    }

    // 总超时保护
    final result = await completer.future.timeout(
      timeout,
      onTimeout: () => throw const PublicIpInfoException('公网 IP 请求超时'),
    );
    return result;
  }

  Future<http.Response> _get(Uri uri, Duration timeout) async {
    final request = http.Request('GET', uri)
      ..headers.addAll(const {
        'Accept': 'application/json,text/plain,text/html',
        'User-Agent': AppConstants.appUserAgent,
      });
    final stopwatch = Stopwatch()..start();
    final responseFuture = _client.send(request);
    late final http.StreamedResponse response;
    try {
      response = await responseFuture.timeout(timeout);
    } on TimeoutException {
      unawaited(
        responseFuture.then<void>(
          (lateResponse) => _cancelResponseStream(lateResponse.stream),
          onError: (Object _, StackTrace __) {},
        ),
      );
      rethrow;
    }

    if ((response.contentLength ?? 0) > maxResponseBytes) {
      await _cancelResponseStream(response.stream);
      throw const PublicIpInfoException('公网 IP 响应超过 64 KiB 限制');
    }

    final remainingMicroseconds =
        timeout.inMicroseconds - stopwatch.elapsedMicroseconds;
    if (remainingMicroseconds <= 0) {
      await _cancelResponseStream(response.stream);
      throw TimeoutException('公网 IP 请求超时', timeout);
    }
    final bytes = await _readBoundedResponse(
      response.stream,
      timeout: Duration(microseconds: remainingMicroseconds),
    );
    return http.Response.bytes(
      bytes,
      response.statusCode,
      request: response.request ?? request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  static Future<Uint8List> _readBoundedResponse(
    Stream<List<int>> stream, {
    required Duration timeout,
  }) async {
    final bytes = BytesBuilder(copy: false);
    final completed = Completer<void>();
    var byteCount = 0;

    late final StreamSubscription<List<int>> subscription;
    subscription = stream.listen(
      (chunk) {
        if (completed.isCompleted) return;
        if (chunk.length > maxResponseBytes - byteCount) {
          completed.completeError(
            const PublicIpInfoException('公网 IP 响应超过 64 KiB 限制'),
          );
          return;
        }
        byteCount += chunk.length;
        bytes.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completed.isCompleted) {
          completed.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!completed.isCompleted) completed.complete();
      },
    );
    final timer = Timer(timeout, () {
      if (!completed.isCompleted) {
        completed.completeError(TimeoutException('公网 IP 响应超时', timeout));
      }
    });

    try {
      await completed.future;
      return bytes.takeBytes();
    } finally {
      timer.cancel();
      try {
        await subscription.cancel().timeout(_responseCancellationTimeout);
      } catch (_) {
        // Preserve the original response error when cancellation itself fails.
      }
    }
  }

  static Future<void> _cancelResponseStream(Stream<List<int>> stream) async {
    try {
      final subscription = stream.listen(
        null,
        onError: (Object _) {},
        cancelOnError: true,
      );
      await subscription.cancel().timeout(_responseCancellationTimeout);
    } catch (_) {
      // The caller still enforces the response boundary even if a custom
      // client reports an error while its body stream is being canceled.
    }
  }

  static PublicIpInfo parse(String body) {
    final jsonInfo = _parseJsonObject(body);
    if (jsonInfo != null) return jsonInfo;

    final scriptInfo = _parseJsonScript(body);
    if (scriptInfo != null) return scriptInfo;

    final dataInfo = _parseDataAttributes(body);
    if (dataInfo != null) return dataInfo;

    final textInfo = _parseLooseText(body);
    if (textInfo != null) return textInfo;

    throw const PublicIpInfoException('未识别到公网 IP 信息');
  }

  static PublicIpInfo? _parseJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      return _fromParts(
        decoded['ip']?.toString(),
        decoded['country_code']?.toString() ??
            decoded['countryCode']?.toString() ??
            decoded['country']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _parseIpOnly(String body) {
    try {
      final decoded = jsonDecode(body);
      final value = decoded is Map ? decoded['ip']?.toString().trim() : null;
      if (value != null && InternetAddress.tryParse(value) != null) return value;
    } catch (_) {}
    // 从纯文本或多行文本中用正则提取IPv4
    final match = RegExp(r'\b((?:\d{1,3}\.){3}\d{1,3})\b').firstMatch(body);
    if (match != null) {
      final value = match.group(1)!;
      return InternetAddress.tryParse(value)?.type == InternetAddressType.IPv4
          ? value
          : null;
    }
    return null;
  }

  static bool _isIpv4(String? value) =>
      InternetAddress.tryParse(value ?? '')?.type == InternetAddressType.IPv4;

  static PublicIpInfo? _parseJsonScript(String body) {
    final match = RegExp(
      r'''<script[^>]*id=["']ip-json["'][^>]*>(.*?)</script>''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(1)?.trim() ?? '');
      if (decoded is! Map) return null;
      return _fromParts(
        decoded['ip']?.toString(),
        decoded['ip-country']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static PublicIpInfo? _parseDataAttributes(String body) {
    final ip = RegExp(
      r'''id=["']ip["'][^>]*data-ip=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(body)?.group(1);
    final country = RegExp(
      r'''id=["']ip-country["'][^>]*data-ip-country=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(body)?.group(1);
    return _fromParts(ip, country);
  }

  static PublicIpInfo? _parseLooseText(String body) {
    final ipv4Match = RegExp(
      r'\b((?:\d{1,3}\.){3}\d{1,3})\s+([A-Za-z]{2})\b',
    ).firstMatch(body);
    final ipv4Info = _fromParts(ipv4Match?.group(1), ipv4Match?.group(2));
    if (ipv4Info != null) return ipv4Info;

    for (final match in RegExp(
      r'([0-9A-Fa-f:]*:[0-9A-Fa-f:]+)\s+([A-Za-z]{2})\b',
    ).allMatches(body)) {
      final info = _fromParts(match.group(1), match.group(2));
      if (info != null) return info;
    }
    return null;
  }

  static PublicIpInfo? _fromParts(String? ip, String? countryCode) {
    final normalizedIp = ip?.trim() ?? '';
    final normalizedCountry = countryCode?.trim().toUpperCase() ?? '';
    if (InternetAddress.tryParse(normalizedIp) == null) return null;
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalizedCountry)) return null;
    return PublicIpInfo(ip: normalizedIp, countryCode: normalizedCountry);
  }
}

class PublicIpInfoException implements Exception {
  const PublicIpInfoException(this.message);

  final String message;

  @override
  String toString() => message;
}
