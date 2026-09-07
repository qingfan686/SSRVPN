import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssrvpn_shared/models/app_settings.dart';
import 'package:ssrvpn_shared/ssrvpn_shared.dart';

class PerAppProxyScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const PerAppProxyScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<PerAppProxyScreen> createState() => _PerAppProxyScreenState();
}

class _PerAppProxyScreenState extends State<PerAppProxyScreen> {
  static const _channel = MethodChannel('com.ssrvpn/native');
  List<Map<String, String>> _apps = [];
  bool _loading = true;
  late PerAppProxyMode _mode;
  late Set<String> _selectedPackages;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _mode = widget.settings.perAppProxyMode;
    _selectedPackages = widget.settings.perAppProxyPackages.toSet();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _loading = true);
    try {
      final result = await _channel.invokeListMethod<Map>('getInstalledApps');
      _apps = (result ?? [])
          .map((e) => Map<String, String>.from(e))
          .toList();
    } catch (e) {
      _apps = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _togglePackage(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
    _saveSettings();
  }

  void _changeMode(PerAppProxyMode mode) {
    setState(() => _mode = mode);
    _saveSettings();
  }

  void _saveSettings() {
    final newSettings = widget.settings.copyWith(
      perAppProxyMode: _mode,
      perAppProxyPackages: _selectedPackages.toList(),
    );
    widget.onSettingsChanged(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _searchQuery.isEmpty
        ? _apps
        : _apps
            .where((app) =>
                app['appName']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                app['packageName']!.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('应用分流'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 模式选择
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '分流模式',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: PerAppProxyMode.values.map((mode) {
                    final selected = _mode == mode;
                    return ChoiceChip(
                      label: Text(mode.chineseName),
                      selected: selected,
                      onSelected: (_) => _changeMode(mode),
                    );
                  }).toList(),
                ),
                if (_mode != PerAppProxyMode.none) ...[
                  const SizedBox(height: 12),
                  Text(
                    _mode == PerAppProxyMode.whitelist
                        ? '仅勾选的应用走代理，其他应用直连'
                        : '勾选的应用不走代理，其他应用走代理',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 搜索框
          if (_mode != PerAppProxyMode.none)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '搜索应用',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          const SizedBox(height: 12),
          // 应用列表
          Expanded(
            child: _mode == PerAppProxyMode.none
                ? Center(
                    child: Text(
                      '当前为全部应用走代理模式',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredApps.isEmpty
                        ? Center(
                            child: Text(
                              '没有找到应用',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredApps.length,
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              final packageName = app['packageName']!;
                              final appName = app['appName']!;
                              final selected =
                                  _selectedPackages.contains(packageName);
                              return CheckboxListTile(
                                title: Text(appName),
                                subtitle: Text(
                                  packageName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                value: selected,
                                onChanged: (_) => _togglePackage(packageName),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
