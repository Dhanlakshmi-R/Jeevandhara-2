/// Lightweight string table for the landing screen (EN + KN placeholders).
class LandingStrings {
  final String languageCode;
  const LandingStrings(this.languageCode);

  static const Map<String, Map<String, String>> _data = {
    'en': {
      'hero1_title': 'Grow more. Earn more. Together.',
      'hero1_sub':
          'Direct market access, live prices, weather & tools — one app for every farmer.',
      'hero2_title': 'Fair prices, no middlemen.',
      'hero2_sub': 'Connect directly with verified traders and mandis.',
      'hero3_title': 'Everything your farm needs.',
      'hero3_sub': 'Weather, tools, inputs and AI quality scans in one place.',
      'cta_get_started': 'Get Started',
      'cta_login': 'Login',
      'trust_strip': '10,000+ farmers · 500+ traders · 24/7 support',
      'how_it_works': 'How it works',
      'offers': 'What Jeevandhara offers',
      'built_for': 'Built for everyone',
      'values': 'What we believe in',
      'footer_cta': 'Ready to grow? Get started in 2 minutes.',
      'footer': 'Jeevandhara — Growing Prosperity, Together.',
    },
    'kn': {
      'hero1_title': 'ಹೆಚ್ಚು ಬೆಳೆಯಿರಿ. ಹೆಚ್ಚು ಗಳಿಸಿರಿ. ಒಟ್ಟಾಗಿ.',
      'hero1_sub':
          'ನೇರ ಮಾರುಕಟ್ಟೆ ಪ್ರವೇಶ, ನೇರ ಬೆಲೆಗಳು, ಹವಾಮಾನ ಮತ್ತು ಉಪಕರಣಗಳು — ಪ್ರತಿ ರೈತನಿಗೆ ಒಂದು ಆ್ಯಪ್.',
      'hero2_title': 'ನ್ಯಾಯಯುತ ಬೆಲೆ, ಮಧ್ಯವರ್ತಿಗಳಿಲ್ಲ.',
      'hero2_sub': 'ಪರಿಶೀಲಿತ ವ್ಯಾಪಾರಿಗಳು ಮತ್ತು ಮಂಡಿಗಳೊಂದಿಗೆ ನೇರ ಸಂಪರ್ಕ.',
      'hero3_title': 'ನಿಮ್ಮ ಫಾರ್ಮ್‌ಗೆ ಬೇಕಾದ್ದೆಲ್ಲ.',
      'hero3_sub': 'ಹವಾಮಾನ, ಉಪಕರಣಗಳು, ಇನ್‌ಪುಟ್‌ಗಳು ಮತ್ತು AI ಗುಣಮಟ್ಟ ಸ್ಕ್ಯಾನ್ ಒಂದೇ ಸ್ಥಳದಲ್ಲಿ.',
      'cta_get_started': 'ಪ್ರಾರಂಭಿಸಿ',
      'cta_login': 'ಲಾಗಿನ್',
      'trust_strip': '10,000+ ರೈತರು · 500+ ವ್ಯಾಪಾರಿಗಳು · 24/7 ಬೆಂಬಲ',
      'how_it_works': 'ಇದು ಹೇಗೆ ಕೆಲಸ ಮಾಡುತ್ತದೆ',
      'offers': 'ಜೀವನಧಾರ ಏನು ನೀಡುತ್ತದೆ',
      'built_for': 'ಎಲ್ಲರಿಗೂ ನಿರ್ಮಿಸಲಾಗಿದೆ',
      'values': 'ನಾವು ನಂಬುವುದು',
      'footer_cta': 'ಬೆಳೆಯಲು ಸಿದ್ಧರಾ? 2 ನಿಮಿಷಗಳಲ್ಲಿ ಪ್ರಾರಂಭಿಸಿ.',
      'footer': 'ಜೀವನಧಾರ — ಸಮೃದ್ಧಿಯನ್ನು ಬೆಳೆಸುವುದು, ಒಟ್ಟಾಗಿ.',
    },
  };

  String t(String key) => _data[languageCode]?[key] ?? _data['en']![key] ?? key;
}