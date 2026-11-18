import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:jeevandhara2/theme/colors.dart';

/// Speaks the given text using the device TTS engine.
class ReadAloudButton extends StatefulWidget {
  const ReadAloudButton({
    super.key,
    required this.text,
    this.language = 'en',
  });

  final String text;
  final String language;

  @override
  State<ReadAloudButton> createState() => _ReadAloudButtonState();
}

class _ReadAloudButtonState extends State<ReadAloudButton> {
  FlutterTts? _tts;
  bool _speaking = false;

  String get _locale {
    switch (widget.language) {
      case 'kn':
        return 'kn-IN';
      case 'hi':
        return 'hi-IN';
      default:
        return 'en-US';
    }
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    _tts ??= FlutterTts();
    if (_speaking) {
      await _tts!.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    await _tts!.setLanguage(_locale);
    await _tts!.setSpeechRate(0.5);
    _tts!.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts!.setErrorHandler((_) {
      if (mounted) setState(() => _speaking = false);
    });
    await _tts!.speak(widget.text);
    if (mounted) setState(() => _speaking = true);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _speaking ? 'Stop reading' : 'Read aloud',
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
            size: 15,
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}