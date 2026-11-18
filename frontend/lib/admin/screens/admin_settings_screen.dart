import 'package:flutter/material.dart';

import '../admin_api.dart';
import '../admin_models.dart';
import '../admin_strings.dart';
import '../admin_theme.dart';
import '../widgets/admin_components.dart';
import '../widgets/admin_states.dart';

/// Screen 4.8 - Settings.
/// 
/// Whitelisted keys only; values coerced server-side. Unknown keys rejected.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _loading = true;
  bool _authFailed = false;
  String? _error;
  List<AdminSetting> _settings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _authFailed = false;
    });
    try {
      final s = await AdminApi.instance.settings();
      if (!mounted) return;
      setState(() {
        _settings = s;
        _loading = false;
      });
    } on AdminAuthException {
      if (!mounted) return;
      setState(() {
        _authFailed = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AdminStrings.of(AK.errorBody);
        _loading = false;
      });
    }
  }

  Future<void> _save(AdminSetting s, dynamic value) async {
    final map = <String, dynamic>{s.key: value};
    try {
      await AdminApi.instance.updateSettings(map);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save setting')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: AdminPageHeader(
        title: AdminStrings.of(AK.navSettings),
        actions: [
          IconButton(
            tooltip: AdminStrings.of(AK.refresh),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            style: IconButton.styleFrom(
              backgroundColor: AdminColors.panel,
              side: const BorderSide(color: AdminColors.border),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_authFailed) return adminNoAccessView();
    if (_loading) return const AdminLoading();
    if (_error != null) return adminErrorView(_load);
    if (_settings.isEmpty) return adminEmptyView();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _settings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _settingCard(_settings[i]),
    );
  }

  Widget _settingCard(AdminSetting s) {
    return AdminPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.key,
                  style: const TextStyle(fontSize: 11.5, color: AdminColors.textMuted),
                ),
                if (s.updatedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Updated ${s.updatedAt!.toIso8601String().split('T')[0]}',
                    style: const TextStyle(fontSize: 11.5, color: AdminColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          _control(s),
        ],
      ),
    );
  }

  Widget _control(AdminSetting s) {
    if (s.isBool) {
      final v = s.boolValue;
      return Switch(value: v, onChanged: (x) => _save(s, x));
    }
    if (s.isInt) {
      final ctrl = TextEditingController(text: s.value ?? s.defaultValue ?? '');
      return SizedBox(
        width: 120,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onSubmitted: (t) {
            final val = int.tryParse(t.trim());
            if (val != null) _save(s, val);
          },
          decoration: const InputDecoration(isDense: true),
        ),
      );
    }
    if (s.isEnum) {
      final vals = s.enumValues;
      final cur = s.value ?? s.defaultValue ?? (vals.isNotEmpty ? vals[0] : '');
      return DropdownButton<String>(
        value: vals.contains(cur) ? cur : (vals.isNotEmpty ? vals[0] : cur),
        items: vals
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          if (v != null) _save(s, v);
        },
      );
    }
    final ctrl = TextEditingController(text: s.value ?? '');
    return SizedBox(
      width: 240,
      child: TextField(
        controller: ctrl,
        onSubmitted: (t) => _save(s, t),
        decoration: const InputDecoration(isDense: true),
      ),
    );
  }
}