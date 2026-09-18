import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/locale.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser? user;
  const ProfileScreen({super.key, this.user});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  final _preferredCrops = const ['Tomato', 'Wheat', 'Onion', 'Groundnut'];
  bool _weatherAlerts = true, _marketAlerts = true, _offerAlerts = true, _smsAlerts = false;
  List<String> _selectedCrops = const ['Tomato', 'Wheat'];

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Jeevandhara?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _apiService.logout();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = widget.user;
    final name = user?.name ?? 'Farmer';
    final role = user?.role ?? 'farmer';
    final roleLabel = role[0].toUpperCase() + role.substring(1);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [c.primary, c.primaryDark]), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            AppAvatar(name: name, size: 56),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              if (user != null) Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.verified, size: 13, color: Colors.white), const SizedBox(width: 4), Text(roleLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))]),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        const _ProfSectionTitle(title: 'Farm Details'),
        AppCard(padding: EdgeInsets.zero, child: Column(children: [
          _ProfRow(icon: Icons.place_outlined, label: 'Farm location', value: 'Dharwad, Karnataka'),
          const Divider(height: 1),
          _ProfRow(icon: Icons.phone_outlined, label: 'Mobile', value: 'Not set'),
          const Divider(height: 1),
          _CropChips(selected: _selectedCrops, options: _preferredCrops, onChanged: (cr) => setState(() => _selectedCrops = _selectedCrops.contains(cr) ? _selectedCrops.where((x) => x != cr).toList() : [..._selectedCrops, cr])),
        ])),
        const SizedBox(height: 20),
        _ProfSectionTitle(title: 'Language'),
        AppCard(padding: EdgeInsets.zero, child: ListenableBuilder(
          listenable: LanguageController.instance,
          builder: (context, _) => Column(children: [
            _RadioCard(title: 'English', subtitle: 'English', selected: LanguageController.instance.lang == AppLang.english, onTap: () => LanguageController.instance.setLang(AppLang.english)),
            const Divider(height: 1),
            _RadioCard(title: '\u0C95\u0CA8\u0CCD\u0CA8\u0CA1 (Kannada)', subtitle: 'Kannada', selected: LanguageController.instance.lang == AppLang.kannada, onTap: () => LanguageController.instance.setLang(AppLang.kannada)),
          ]),
        )),
        const SizedBox(height: 20),
        const _ProfSectionTitle(title: 'Appearance'),
        AppCard(padding: EdgeInsets.zero, child: ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (context, _) {
            final mode = ThemeController.instance.mode;
            return Column(children: [
              _RadioCard(title: 'System theme', subtitle: 'Follow phone / browser setting', selected: mode == ThemeMode.system, onTap: () => ThemeController.instance.setMode(ThemeMode.system)),
              const Divider(height: 1),
              _RadioCard(title: 'Light', subtitle: 'Bright, crisp interface', selected: mode == ThemeMode.light, onTap: () => ThemeController.instance.setMode(ThemeMode.light)),
              const Divider(height: 1),
              _RadioCard(title: 'Dark', subtitle: 'Low-glare, night-friendly', selected: mode == ThemeMode.dark, onTap: () => ThemeController.instance.setMode(ThemeMode.dark)),
            ]);
          },
        )),
        const SizedBox(height: 20),
        const _ProfSectionTitle(title: 'Notification Settings'),
        AppCard(padding: EdgeInsets.zero, child: Column(children: [
          _SwitchRow(icon: Icons.wb_sunny_outlined, label: 'Weather alerts', value: _weatherAlerts, onChanged: (v) => setState(() => _weatherAlerts = v)),
          const Divider(height: 1),
          _SwitchRow(icon: Icons.trending_up, label: 'Market price alerts', value: _marketAlerts, onChanged: (v) => setState(() => _marketAlerts = v)),
          const Divider(height: 1),
          _SwitchRow(icon: Icons.handshake_outlined, label: 'Trade offer alerts', value: _offerAlerts, onChanged: (v) => setState(() => _offerAlerts = v)),
          const Divider(height: 1),
          _SwitchRow(icon: Icons.sms_outlined, label: 'SMS alerts', value: _smsAlerts, onChanged: (v) => setState(() => _smsAlerts = v)),
        ])),
        const SizedBox(height: 24),
        AppPrimaryButton(label: 'Save Settings', icon: Icons.save_outlined, onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')))),
        const SizedBox(height: 12),
        AppOutlineButton(label: 'Log Out', icon: Icons.logout, onPressed: _confirmLogout),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ProfSectionTitle extends StatelessWidget {
  final String title;
  const _ProfSectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 2), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: context.colors.textSecondary)));
}

class _ProfRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ProfRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14), leading: Icon(icon, color: context.colors.primary), title: Text(label, style: const TextStyle(fontSize: 14)), trailing: Text(value, style: TextStyle(fontSize: 13.5, color: context.colors.textPrimary, fontWeight: FontWeight.w600)));
}

class _CropChips extends StatelessWidget {
  final List<String> selected, options;
  final ValueChanged<String> onChanged;
  const _CropChips({required this.selected, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Preferred crops', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: options.map((cr) => FilterChip(
        label: Text(cr), selected: selected.contains(cr), onSelected: (_) => onChanged(cr),
        selectedColor: context.colors.primaryLight, checkmarkColor: context.colors.primaryDark,
        side: BorderSide(color: selected.contains(cr) ? context.colors.primary : context.colors.border),
        labelStyle: TextStyle(color: selected.contains(cr) ? context.colors.primaryDark : context.colors.textSecondary, fontWeight: FontWeight.w600),
      )).toList()),
    ]),
  );
}

class _RadioCard extends StatelessWidget {
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RadioCard({required this.title, required this.subtitle, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    leading: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? context.colors.primary : context.colors.textSecondary),
    title: Text(title, style: TextStyle(fontSize: 14.5, color: context.colors.textPrimary)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
    trailing: selected ? Container(width: 22, height: 22, decoration: BoxDecoration(color: context.colors.primary, shape: BoxShape.circle), child: const Icon(Icons.check, size: 14, color: Colors.white)) : null,
    onTap: onTap,
  );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.icon, required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    secondary: Icon(icon, color: context.colors.primary),
    title: Text(label, style: const TextStyle(fontSize: 14.5)),
    value: value,
    activeTrackColor: context.colors.primary.withValues(alpha: 0.45),
    activeThumbColor: context.colors.primary,
    onChanged: onChanged,
  );
}