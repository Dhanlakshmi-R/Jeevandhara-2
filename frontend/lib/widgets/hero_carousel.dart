import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'ui/network_or_asset_image.dart';

/// A 3-slide auto-advancing hero carousel with image overlay and two CTAs.
class HeroCarousel extends StatefulWidget {
  final List<HeroSlide> slides;
  final Duration autoAdvance;
  final Widget primaryButton;
  final Widget secondaryButton;

  const HeroCarousel({
    super.key,
    required this.slides,
    this.autoAdvance = const Duration(seconds: 5),
    required this.primaryButton,
    required this.secondaryButton,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class HeroSlide {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? assetPath;
  final Color gradientStart;
  final Color gradientEnd;

  const HeroSlide({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.assetPath,
    this.gradientStart = const Color(0xFF1F6B45),
    this.gradientEnd = const Color(0xFF0F3D28),
  });
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final PageController _controller;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
      if (reduceMotion) return;
      _timer = Timer.periodic(widget.autoAdvance, (_) {
        if (!mounted) return;
        final next = (_index + 1) % widget.slides.length;
        if (_controller.hasClients) {
          _controller.animateToPage(next,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut);
        }
        setState(() => _index = next);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final slide = widget.slides[i];
              return _SlideView(
                slide: slide,
                primaryButton: widget.primaryButton,
                secondaryButton: widget.secondaryButton,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.slides.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? context.colors.primary
                    : context.colors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SlideView extends StatelessWidget {
  final HeroSlide slide;
  final Widget primaryButton;
  final Widget secondaryButton;

  const _SlideView({
    required this.slide,
    required this.primaryButton,
    required this.secondaryButton,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetworkOrAssetImage(
          url: slide.imageUrl,
          assetPath: slide.assetPath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          semanticLabel: slide.title,
        ),
        // gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.75),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                slide.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                slide.subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [primaryButton, secondaryButton],
              ),
            ],
          ),
        ),
      ],
    );
  }
}