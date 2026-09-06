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

  final http.Client _client;

  Future<PublicIpInfo> fetch({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // IPv4功能已禁用，直接返回空
    throw const PublicIpInfoException('IPv4功能已禁用');
  }

  Future<http.Response> _get(Uri uri, Duration timeout) {
    return _client.get(uri).timeout(timeout);
  }

  static PublicIpInfo parse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('响应不是JSON对象');
      }
      final ip = decoded['ip']?.toString().trim();
      if (ip == null || ip.isEmpty) {
        throw const FormatException('响应中缺少ip字段');
      }
      final country = decoded['country']?.toString().trim();
      return PublicIpInfo(
        ip: ip,
        countryCode: country ?? '',
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('解析IP信息失败: $error');
    }
  }

  static String? _parseIpOnly(String body) {
    try {
      final decoded = jsonDecode(body);
      final value = decoded is Map ? decoded['ip']?.toString().trim() : null;
      if (value != null && InternetAddress.tryParse(value) != null) return value;
    } catch (_) {}
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
}

class PublicIpInfoException implements Exception {
  final String message;
  const PublicIpInfoException(this.message);

  @override
  String toString() => message;
}
