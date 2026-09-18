import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/layout.dart';
import '../widgets/ui/buttons.dart';
import '../widgets/ui/cards.dart';

class QualityAnalysisScreen extends StatefulWidget {
  const QualityAnalysisScreen({super.key});

  @override
  State<QualityAnalysisScreen> createState() => _QualityAnalysisScreenState();
}

enum _Phase { idle, uploading, analyzing, done }

class _QualityAnalysisScreenState extends State<QualityAnalysisScreen> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  Timer? _timer;

  int _healthScore = 0;
  String _grade = '';
  String _risk = '';
  List<String> _tags = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnalysis() {
    if (_phase == _Phase.analyzing) return;
    setState(() {
      _phase = _Phase.uploading;
      _progress = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted) return;
      setState(() => _progress += 0.02 + (t.tick % 3) * 0.005);
      if (_progress >= 0.45 && _phase == _Phase.uploading) {
        setState(() => _phase = _Phase.analyzing);
      }
      if (_progress >= 1) {
        t.cancel();
        _finishAnalysis();
      }
    });
  }

  void _finishAnalysis() {
    setState(() {
      _phase = _Phase.done;
      _healthScore = 87;
      _grade = 'Grade A';
      _risk = 'Low';
      _tags = [
        'Healthy leaves - no disease spotted',
        'Good cleanliness - no foreign matter',
        'Uniform size & ripeness',
        'Minor cosmetic blemish on 2% fruits',
      ];
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.idle;
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Quality Analysis'),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: ThemeToggle())],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUploadArea(),
          if (_phase != _Phase.idle) ...[
            const SizedBox(height: 20),
            _buildProgress(),
          ],
          const SizedBox(height: 16),
          Text(
            'How it works',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _StepRow(icon: Icons.camera_alt_outlined, text: 'Take or upload a clear photo of your crop'),
                SizedBox(height: 12),
                _StepRow(icon: Icons.smart_toy_outlined, text: 'AI checks health, disease, grade & cleanliness'),
                SizedBox(height: 12),
                _StepRow(icon: Icons.insights_outlined, text: 'Get a quality score and suggested price range'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    final c = context.colors;
    if (_phase == _Phase.done) {
      return _ResultCard(
        healthScore: _healthScore,
        grade: _grade,
        risk: _risk,
        tags: _tags,
        onReset: _reset,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: c.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_a_photo_outlined, size: 34, color: c.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload crop photo or video',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Drag & drop, or tap to browse\n(JPEG, PNG, MP4 \u00B7 max 50 MB)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          AppPrimaryButton(label: 'Analyze Crop Quality', icon: Icons.biotech, onPressed: _startAnalysis),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final c = context.colors;
    final stage = _phase == _Phase.uploading ? 'Uploading media\u2026' : 'AI analyzing quality\u2026';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _phase == _Phase.analyzing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: c.primary),
                    )
                  : Icon(Icons.cloud_upload_outlined, color: c.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                stage,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: c.primaryLight.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation(c.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StepRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: c.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final int healthScore;
  final String grade;
  final String risk;
  final List<String> tags;
  final VoidCallback onReset;

  const _ResultCard({
    required this.healthScore,
    required this.grade,
    required this.risk,
    required this.tags,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.primaryLight, c.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt, color: c.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'AI Analysis Complete',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: healthScore / 100,
                      strokeWidth: 9,
                      backgroundColor: c.surface,
                      valueColor: AlwaysStoppedAnimation(c.primary),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$healthScore',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                          Text('/100', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResultLine(label: 'Quality grade', value: grade, icon: Icons.verified, color: c.positive),
                    const SizedBox(height: 10),
                    _ResultLine(
                      label: 'Disease risk',
                      value: risk,
                      icon: Icons.health_and_safety_outlined,
                      color: c.positive,
                    ),
                    const SizedBox(height: 10),
                    _ResultLine(
                      label: 'Suggested price',
                      value: '\u20B927 \u2013 \u20B931/kg',
                      icon: Icons.currency_rupee,
                      color: c.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: c.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 13, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AppTonalButton(label: 'Analyze another crop', onPressed: onReset),
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultLine({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }
}