import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'agri_scene.dart';
import 'layout.dart';

/// Shared split-screen shell for auth pages.
///
/// - Desktop/tablet (>= 860px): agriculture illustration panel beside the
///   form card.
/// - Mobile: compact illustration header above the form.
/// A light/dark `ThemeToggle` sits in the top-right corner on every size.
class AuthShell extends StatelessWidget {
  final String headline;
  final String subhead;
  final Widget child;
  final AgriSceneKind scene;
  final String panelTitle;
  final String panelSubtitle;

  const AuthShell({
    super.key,
    required this.headline,
    required this.subhead,
    required this.child,
    this.scene = AgriSceneKind.sunrise,
    this.panelTitle = 'Jeevandhara',
    this.panelSubtitle = 'Growing Prosperity, Together.',
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isSplit = width >= 860;

    if (isSplit) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _SidePanel(scene: scene, title: panelTitle, subtitle: panelSubtitle)),
            Expanded(
              child: _FormPane(
                headline: headline,
                subhead: subhead,
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MobileHeader(scene: scene, title: panelTitle, subtitle: panelSubtitle),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _FormCard(child: child),
              ),
            ),
            const SizedBox(height: 8),
            // Placeholder to keep the lifted card balanced at the bottom.
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Deep-green illustration panel for wide screens.
class _SidePanel extends StatelessWidget {
  final AgriSceneKind scene;
  final String title;
  final String subtitle;

  const _SidePanel({
    required this.scene,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.brandGradientStart, c.primaryDark, c.brandGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _blob(260, 0.10)),
          Positioned(bottom: -120, left: -70, child: _blob(320, 0.08)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _BrandMark(c),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      const ThemeToggle(activeColor: Colors.white),
                    ],
                  ),
                  const Spacer(),
                  AgriScene(kind: scene, onDark: true, width: 460, height: 330),
                  const Spacer(),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 26,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A digital platform connecting farmers, traders and '
                    'vendors with fair pricing \u00b7 live market data \u00b7 '
                    'weather intelligence \u00b7 trusted tools \u2014 in one app.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _TrustPill(icon: Icons.shield_outlined, label: 'Secure'),
                      _TrustPill(icon: Icons.verified_user_outlined, label: 'Verified'),
                      _TrustPill(icon: Icons.language, label: 'EN \u00b7 \u0c95\u0ca8\u0ccd\u0ca8\u0ca1'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark(this.c);
  final ThemeColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
    );
  }
}

class _TrustPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile compact hero: brand + scene + title.
class _MobileHeader extends StatelessWidget {
  final AgriSceneKind scene;
  final String title;
  final String subtitle;

  const _MobileHeader({
    required this.scene,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 70),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.brandGradientStart, c.primaryDark, c.brandGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -30, top: -30, child: Icon(Icons.eco, size: 110, color: Colors.white.withValues(alpha: 0.10))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BrandMark(c),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  const ThemeToggle(activeColor: Colors.white),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 300,
                  height: 170,
                  child: AgriScene(kind: scene, onDark: true),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Scrollable form pane for wide screens with centered card.
class _FormPane extends StatelessWidget {
  final String headline;
  final String subhead;
  final Widget child;

  const _FormPane({
    required this.headline,
    required this.subhead,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height - 80,
            maxWidth: 440,
          ),
          child: Align(
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: ThemeToggle(),
                ),
                const SizedBox(height: 12),
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subhead,
                  style: TextStyle(fontSize: 14.5, color: c.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                _FormCard(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Elevated card used on both layouts.
class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.divider),
        boxShadow: [
          BoxShadow(
            color: c.isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.09),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}