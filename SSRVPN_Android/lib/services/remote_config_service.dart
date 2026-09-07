import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ssrvpn_shared/ssrvpn_shared.dart';

/// 远程配置服务
///
/// 从云端 JSON 拉取：
/// - subscriptions: 多条订阅链接（可远程增删改）
/// - announcement_text: 关于弹窗公告内容（可远程修改）
/// - update: 云更新信息（最新版本号、下载地址、强制更新开关、更新日志）
///
/// 网络失败时全部回退到本地内置配置，保证 APP 始终可用。
class RemoteConfigService {
  /// 远程配置地址（托管在 GitHub Pages / Cloudflare Pages 等静态托管）
  static const String remoteConfigUrl =
      'https://raw.githubusercontent.com/qingfan686/SSRVPN/main/config.json';

  /// 本地内置订阅（网络失败时的回退）
  static const List<RemoteSubscription> fallbackSubscriptions = [
    RemoteSubscription(
      name: '清凡VPN',
      url:
          'https://xn--jxqr14o.qingfanovo.cc.cd/sub?token=9cb8f7f4575538f0b79921054bf88e95',
    ),
  ];

  /// 本地内置公告（网络失败时的回退）
  static const String fallbackAnnouncement =
      '清凡VPN 致力于为用户提供稳定、快速的网络加速服务。\n'
      '本软件完全免费，请勿用于商业用途。\n'
      '使用过程中如有问题，请联系作者反馈。';

  static const String fallbackDownloadUrl =
      'https://share.weiyun.com/CLvUUNac';

  static RemoteConfig? _cached;
  static DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
  static bool _fetchInFlight = false;

  static const Duration _cacheTtl = Duration(minutes: 10);

  static RemoteConfig get cached => _cached ?? RemoteConfig.empty();

  /// 获取远程配置（带缓存）
  static Future<RemoteConfig> fetch({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cached != null &&
        now.difference(_lastFetch) < _cacheTtl) {
      return _cached!;
    }
    if (_fetchInFlight && _cached != null) return _cached!;
    _fetchInFlight = true;
    try {
      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse(remoteConfigUrl))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final config = RemoteConfig.fromJson(json);
          _cached = config;
          _lastFetch = now;
          return config;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      AppLogger.warning('RemoteConfig', '拉取远程配置失败: $e');
    } finally {
      _fetchInFlight = false;
    }
    if (_cached != null) return _cached!;
    return RemoteConfig.empty();
  }

  /// 应用启动时调用，预拉取远程配置（不阻塞启动）
  static Future<void> warmUp() async {
    try {
      await fetch();
    } catch (_) {}
  }
}

/// 远程订阅条目
@immutable
class RemoteSubscription {
  final String name;
  final String url;

  const RemoteSubscription({required this.name, required this.url});

  factory RemoteSubscription.fromJson(Map<String, dynamic> json) {
    return RemoteSubscription(
      name: json['name']?.toString()?.trim() ?? '订阅',
      url: json['url']?.toString()?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}

/// 远程配置数据模型
@immutable
class RemoteConfig {
  final List<RemoteSubscription> subscriptions;
  final String announcementText;
  final bool announcementEnabled;
  final bool updateEnabled;
  final bool forceUpdate;
  final String minimumAllowVersion;
  final String latestVersion;
  final String downloadUrl;
  final String updateLog;

  const RemoteConfig({
    required this.subscriptions,
    required this.announcementText,
    required this.announcementEnabled,
    required this.updateEnabled,
    required this.forceUpdate,
    required this.minimumAllowVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.updateLog,
  });

  factory RemoteConfig.empty() {
    return RemoteConfig(
      subscriptions: RemoteConfigService.fallbackSubscriptions,
      announcementText: RemoteConfigService.fallbackAnnouncement,
      announcementEnabled: true,
      updateEnabled: false,
      forceUpdate: false,
      minimumAllowVersion: AppConstants.appVersion,
      latestVersion: AppConstants.appVersion,
      downloadUrl: RemoteConfigService.fallbackDownloadUrl,
      updateLog: '',
    );
  }

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    final subscriptionsRaw = json['subscriptions'];
    List<RemoteSubscription> subscriptions;
    if (subscriptionsRaw is List && subscriptionsRaw.isNotEmpty) {
      subscriptions = subscriptionsRaw
          .whereType<Map>()
          .map((e) => RemoteSubscription.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .where((s) => s.url.isNotEmpty)
          .toList();
    } else {
      // 兼容旧版单条订阅字段
      final singleUrl = json['subscription_url']?.toString()?.trim();
      subscriptions = singleUrl != null && singleUrl.isNotEmpty
          ? [RemoteSubscription(name: '清凡VPN', url: singleUrl)]
          : RemoteConfigService.fallbackSubscriptions;
    }
    if (subscriptions.isEmpty) {
      subscriptions = RemoteConfigService.fallbackSubscriptions;
    }

    final updateRaw = json['update'];
    final updateMap = updateRaw is Map
        ? Map<String, dynamic>.from(updateRaw as Map)
        : <String, dynamic>{};

    return RemoteConfig(
      subscriptions: subscriptions,
      announcementText:
          json['announcement_text']?.toString()?.trim() ??
              RemoteConfigService.fallbackAnnouncement,
      announcementEnabled: json['announcement_enable'] as bool? ?? true,
      updateEnabled: updateMap['enable'] as bool? ?? false,
      forceUpdate: updateMap['force_update'] as bool? ?? false,
      minimumAllowVersion:
          updateMap['minimum_allow_version']?.toString()?.trim() ??
              AppConstants.appVersion,
      latestVersion:
          updateMap['latest_version']?.toString()?.trim() ??
              AppConstants.appVersion,
      downloadUrl:
          updateMap['download_url']?.toString()?.trim() ??
              RemoteConfigService.fallbackDownloadUrl,
      updateLog: updateMap['update_log']?.toString()?.trim() ?? '',
    );
  }
}

/// 版本号比较工具
class VersionComparator {
  /// 返回 true 当 [a] < [b]（语义化版本比较）
  static bool isLower(String a, String b) {
    final aParts = _split(a);
    final bParts = _split(b);
    final len = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av < bv;
    }
    return false;
  }

  static List<int> _split(String version) {
    final cleaned = version
        .trim()
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .split('.')
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    return cleaned.isEmpty ? [0] : cleaned;
  }
}
