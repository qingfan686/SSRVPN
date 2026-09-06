import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../constants/app_constants.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    this.sha256,
    this.sourceHost,
    this.fallbackDownloadUrl,
  });

  final String version;
  final String downloadUrl;
  final String changelog;
  final String? sha256;
  final String? sourceHost;
  final String? fallbackDownloadUrl;
}

class _ReleaseAsset {
  const _ReleaseAsset({
    required this.name,
    required this.downloadUrl,
  });

  final String name;
  final String downloadUrl;
}

/// A newer version exists, but no verified installer can be offered yet.
class UpdateNotReady implements Exception {
  const UpdateNotReady(this.version);

  final String version;
  String get userMessage => '发现新版本 v$version，但当前平台安装包或校验信息暂不可用，请稍后重新检查';

  @override
  String toString() => userMessage;
}

class UpdateChecker {
  static String checkFailureMessage(Object error) =>
      error is UpdateNotReady ? error.userMessage : '检查更新失败，请检查网络后重试';

  static const int maxMetadataResponseBytes = 1024 * 1024;
  static const int _maxChecksumResponseBytes = 4096;
  static const String owner = 'qingfan686';
  static const String repo = 'SSRVPN';
  static final Uri kataUpdateUrl = Uri.parse(
    'https://qingfan686.github.io/SSRVPN/update.json',
  );

  static Future<AppUpdateInfo?> checkLatest({
    required String currentVersion,
    required String assetExtension,
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final ownsClient = client == null;
    // 强制走本地mihomo代理，避免国内网络访问github.io被墙
    final httpClient = client ?? _proxyClient();
    try {
      return await _checkKata(
        currentVersion: currentVersion,
        assetExtension: assetExtension,
        client: httpClient,
        timeout: timeout,
      );
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  /// 创建走本地代理的HTTP客户端
  static http.Client _proxyClient() {
    final ioClient = HttpClient()
      ..findProxy = (uri) => 'PROXY 127.0.0.1:7890';
    return IOClient(ioClient);
  }

  static Future<AppUpdateInfo?> _checkKata({
    required String currentVersion,
    required String assetExtension,
    required http.Client client,
    required Duration timeout,
  }) async {
    final response = await _boundedGet(
      kataUpdateUrl,
      client: client,
      timeout: timeout,
      maxBytes: maxMetadataResponseBytes,
      headers: {
        'User-Agent': AppConstants.appUserAgent,
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Kata update metadata returned HTTP ${response.statusCode}',
        uri: kataUpdateUrl,
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Kata update metadata is not an object');
    }

    final latestVersion = (data['version']?.toString() ?? '').trim();
    if (!_isValidVersion(latestVersion)) {
      throw const FormatException('Kata release version is invalid');
    }
    if (compareVersions(latestVersion, currentVersion) <= 0) return null;

    final downloadUrl = data['download_url']?.toString() ?? '';
    if (downloadUrl.isEmpty) throw UpdateNotReady(latestVersion);
    final changelog = data['changelog']?.toString() ?? '';
    final sha256 = data['sha256']?.toString();
    final fallbackDownloadUrl = data['fallback_download_url']?.toString();
    final sourceHost = Uri.tryParse(downloadUrl)?.host;

    return AppUpdateInfo(
      version: latestVersion,
      downloadUrl: downloadUrl,
      changelog: changelog,
      sha256: sha256,
      sourceHost: sourceHost,
      fallbackDownloadUrl: fallbackDownloadUrl,
    );
  }

  static bool _isValidVersion(String version) =>
      RegExp(r'^\d+(?:\.\d+){1,3}$').hasMatch(version);

  static int compareVersions(String a, String b) {
    final aVersion = _parseComparableVersion(a);
    final bVersion = _parseComparableVersion(b);
    final aParts = aVersion.core;
    final bParts = bVersion.core;
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final ai = i < aParts.length ? aParts[i] : 0;
      final bi = i < bParts.length ? bParts[i] : 0;
      if (ai > bi) return 1;
      if (ai < bi) return -1;
    }

    final aPrerelease = aVersion.prerelease;
    final bPrerelease = bVersion.prerelease;
    if (aPrerelease.isEmpty && bPrerelease.isEmpty) return 0;
    if (aPrerelease.isEmpty) return 1;
    if (bPrerelease.isEmpty) return -1;
    final prereleaseLength = aPrerelease.length > bPrerelease.length
        ? aPrerelease.length
        : bPrerelease.length;
    for (var i = 0; i < prereleaseLength; i++) {
      if (i >= aPrerelease.length) return -1;
      if (i >= bPrerelease.length) return 1;
      final aIdentifier = aPrerelease[i];
      final bIdentifier = bPrerelease[i];
      final aNumber = int.tryParse(aIdentifier);
      final bNumber = int.tryParse(bIdentifier);
      if (aNumber != null && bNumber != null) {
        if (aNumber > bNumber) return 1;
        if (aNumber < bNumber) return -1;
        continue;
      }
      if (aNumber != null) return -1;
      if (bNumber != null) return 1;
      final lexical = aIdentifier.compareTo(bIdentifier);
      if (lexical != 0) return lexical.sign;
    }
    return 0;
  }

  static ({List<int> core, List<String> prerelease}) _parseComparableVersion(
      String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(
      r'^(\d+(?:\.\d+)*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
      r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
    ).firstMatch(normalized);
    if (match != null) {
      return (
        core: match.group(1)!.split('.').map(int.parse).toList(),
        prerelease: match.group(2)?.split('.') ?? const <String>[],
      );
    }
    return (
      core:
          normalized.split('.').map((part) => int.tryParse(part) ?? 0).toList(),
      prerelease: const <String>[],
    );
  }

  static List<_ReleaseAsset> _releaseAssets(Object? assets) {
    if (assets is! List) return const [];
    final result = <_ReleaseAsset>[];
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = asset['name']?.toString();
      final candidate = asset['browser_download_url']?.toString();
      if (name != null &&
          name.isNotEmpty &&
          candidate != null &&
          _isSecureDownloadUrl(candidate)) {
        result.add(_ReleaseAsset(name: name, downloadUrl: candidate));
      }
    }
    return result;
  }

  static _ReleaseAsset? _assetFor(
    List<_ReleaseAsset> assets,
    String assetExtension,
  ) {
    final wantedName = _assetNameForExtension(assetExtension);
    if (wantedName == null) return null;
    for (final asset in assets) {
      if (asset.name == wantedName) return asset;
    }
    return null;
  }

  static String? _assetNameForExtension(String assetExtension) {
    return switch (assetExtension.trim().toLowerCase()) {
      '.apk' => 'SSRVPN.apk',
      '.dmg' => 'SSRVPN.dmg',
      '.exe' => 'SSRVPN_Setup.exe',
      _ => null,
    };
  }

  static bool _isSecureDownloadUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  static Future<String?> _sha256ForAsset(
    List<_ReleaseAsset> assets,
    _ReleaseAsset asset,
    String version,
    http.Client client,
    Duration timeout,
  ) async {
    final checksumName = '${asset.name}.sha256'.toLowerCase();
    _ReleaseAsset? checksumAsset;
    for (final candidate in assets) {
      if (candidate.name.toLowerCase() == checksumName) {
        checksumAsset = candidate;
        break;
      }
    }
    if (checksumAsset == null) return null;
    if (!_isExpectedGitHubAssetUrl(
      checksumAsset.downloadUrl,
      version: version,
      assetName: checksumAsset.name,
    )) {
      return null;
    }

    final response = await _boundedGet(
      Uri.parse(checksumAsset.downloadUrl),
      client: client,
      timeout: timeout,
      maxBytes: _maxChecksumResponseBytes,
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub checksum returned HTTP ${response.statusCode}',
        uri: Uri.parse(checksumAsset.downloadUrl),
      );
    }
    final checksumLine = RegExp(
      '^\\s*([a-fA-F0-9]{64})\\s+\\*?${RegExp.escape(asset.name)}\\s*\$',
      multiLine: true,
    ).firstMatch(response.body);
    return checksumLine?.group(1)?.toLowerCase();
  }

  static Future<_BoundedTextResponse> _boundedGet(
    Uri uri, {
    required http.Client client,
    required Duration timeout,
    required int maxBytes,
    Map<String, String>? headers,
  }) async {
    final clock = Stopwatch()..start();
    final request = http.Request('GET', uri);
    if (headers != null) request.headers.addAll(headers);
    final responseFuture = client.send(request);
    late final http.StreamedResponse response;
    try {
      response = await responseFuture.timeout(_remainingTime(clock, timeout));
    } catch (_) {
      unawaited(
        responseFuture.then<void>(
          _cancelUnusedResponse,
          onError: (Object _, StackTrace __) {},
        ),
      );
      rethrow;
    }
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maxBytes) {
      await _cancelUnusedResponse(response);
      throw StateError('update response exceeds $maxBytes bytes');
    }
    final bytes = BytesBuilder(copy: false);
    var received = 0;
    final iterator = StreamIterator<List<int>>(response.stream);
    try {
      while (
          await iterator.moveNext().timeout(_remainingTime(clock, timeout))) {
        final chunk = iterator.current;
        received += chunk.length;
        if (received > maxBytes) {
          throw StateError('update response exceeds $maxBytes bytes');
        }
        bytes.add(chunk);
      }
    } finally {
      await iterator.cancel();
    }
    return _BoundedTextResponse(
      statusCode: response.statusCode,
      body: utf8.decode(bytes.takeBytes()),
    );
  }

  static Duration _remainingTime(Stopwatch clock, Duration timeout) {
    final remaining = timeout - clock.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('update request timed out');
    }
    return remaining;
  }

  static Future<void> _cancelUnusedResponse(
    http.StreamedResponse response,
  ) async {
    try {
      final subscription = response.stream.listen((_) {});
      await subscription.cancel();
    } catch (_) {
      // Preserve the request failure that made this response obsolete.
    }
  }

  static bool _isExpectedGitHubAssetUrl(
    String value, {
    required String version,
    required String assetName,
  }) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.path == '/$owner/$repo/releases/download/v$version/$assetName';
  }

  static String _buildChangelog(
    String body, {
    required String? sourceHost,
    required String? sha256,
  }) {
    final lines = <String>[];
    final trimmedBody = _normalizeReleaseNotes(body.trim());
    if (trimmedBody.isNotEmpty) lines.add(trimmedBody);
    if (sourceHost != null && sourceHost.isNotEmpty) {
      lines.add('下载来源: $sourceHost');
    }
    if (sha256 != null && sha256.isNotEmpty) {
      lines.add('SHA256: $sha256');
    }
    return lines.join('\n\n');
  }

  static String _normalizeReleaseNotes(String body) {
    if (body.isEmpty) return body;
    final replacements = <String, String>{
      '### Downloads': '### 下载',
      '### Added': '### 新增',
      '### Changed': '### 变更',
      '### Deprecated': '### 废弃',
      '### Removed': '### 移除',
      '### Fixed': '### 修复',
      '### Security': '### 安全',
      '| Platform | File | Checksum |': '| 平台 | 文件 | 校验和 |',
      'Verify checksums:': '校验 SHA256：',
    };
    var normalized = body;
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized;
  }
}

class _BoundedTextResponse {
  const _BoundedTextResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
