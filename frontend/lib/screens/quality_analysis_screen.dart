import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jeevandhara2/ai/service/ai_service.dart';
import 'package:jeevandhara2/theme/colors.dart';
import 'package:jeevandhara2/widgets/layout.dart';
import 'package:jeevandhara2/widgets/ui/buttons.dart';
import 'package:jeevandhara2/widgets/ui/cards.dart';

class QualityAnalysisScreen extends StatefulWidget {
  const QualityAnalysisScreen({super.key});

  @override
  State<QualityAnalysisScreen> createState() => _QualityAnalysisScreenState();
}

class _QualityAnalysisScreenState extends State<QualityAnalysisScreen> {
  final AiService _service = AiService();
  final ImagePicker _picker = ImagePicker();

  String? _imagePath;
  bool _analyzing = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) return;

      setState(() {
        _imagePath = file.path;
        _analyzing = true;
        _result = null;
        _error = null;
      });

      try {
        final data = await _service.analyzeQuality(
          filename: file.name,
          cropName: '',
          language: 'en',
        );
        if (!mounted) return;
        if (data.isEmpty) {
          setState(() => _error = 'Analysis failed. Please try again.');
        } else {
          setState(() => _result = data);
        }
      } catch (_) {
        if (mounted) setState(() => _error = 'Analysis failed. Please try again.');
      } finally {
        if (mounted) setState(() => _analyzing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not open image picker: $e');
      }
    }
  }

  void _reset() {
    setState(() {
      _imagePath = null;
      _result = null;
      _error = null;
      _analyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Quality Analysis'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: ThemeToggle())
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUploadArea(c),
          if (_analyzing) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: c.warning)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResult(c, _result!),
          ],
          const SizedBox(height: 16),
          Text(
            'How it works',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepRow(
                    icon: Icons.camera_alt_outlined,
                    text: 'Take or upload a clear photo of your crop'),
                SizedBox(height: 12),
                _StepRow(
                    icon: Icons.smart_toy_outlined,
                    text: 'AI checks health, disease, grade & cleanliness'),
                SizedBox(height: 12),
                _StepRow(
                    icon: Icons.insights_outlined,
                    text: 'Get a quality score and suggested price range'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea(ThemeColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.primary.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Column(
        children: [
          if (_imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(
                      _imagePath!,
                      height: 180,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_imagePath!),
                      height: 180,
                      fit: BoxFit.cover,
                    ),
            )
          else
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
            _imagePath == null
                ? 'Upload crop photo'
                : 'Selected image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  onPressed: _analyzing ? null : () => _pickAndAnalyze(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Camera',
                  icon: Icons.camera_alt_outlined,
                  onPressed: _analyzing ? null : () => _pickAndAnalyze(ImageSource.camera),
                ),
              ),
            ],
          ),
          if (_imagePath != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: _reset, child: const Text('Clear')),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(ThemeColors c, Map<String, dynamic> data) {
    final cropName = (data['crop_name'] ?? 'Unknown crop').toString();
    final grade = (data['quality_grade'] ?? '').toString();
    final score = (data['health_score'] is num) ? (data['health_score'] as num).toInt() : 0;
    final risk = (data['disease_risk'] ?? '').toString();
    final uses = (data['uses'] ?? '').toString();
    final harmful = (data['harmful'] ?? '').toString();
    final notes = (data['notes'] ?? '').toString();

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
          Text('AI Analysis Complete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 12),
          _ResultLine(label: 'Crop name', value: cropName, icon: Icons.eco, color: c.primary),
          const SizedBox(height: 8),
          _ResultLine(label: 'Quality grade', value: grade, icon: Icons.verified, color: c.positive),
          const SizedBox(height: 8),
          _ResultLine(label: 'Health score', value: '$score/100', icon: Icons.favorite, color: c.primary),
          const SizedBox(height: 8),
          _ResultLine(label: 'Disease risk', value: risk, icon: Icons.health_and_safety_outlined, color: c.positive),
          const SizedBox(height: 12),
          Text('Uses', style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
          Text(uses, style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 8),
          Text('Harmful?', style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
          Text(harmful, style: TextStyle(color: c.textSecondary)),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Notes', style: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary)),
            Text(notes, style: TextStyle(color: c.textSecondary)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppTonalButton(label: 'Analyze another crop', onPressed: _reset),
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
      ],
    );
  }
}