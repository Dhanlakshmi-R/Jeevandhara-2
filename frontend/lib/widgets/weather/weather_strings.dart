import 'package:jeevandhara2/models/weather_data.dart';

/// Languages the weather panel can speak and display.
enum WeatherLang { en, kn }

extension WeatherLangX on WeatherLang {
  String get code => this == WeatherLang.kn ? 'kn' : 'en';

  /// BCP-47 locale handed to the text-to-speech engine.
  String get ttsLocale => this == WeatherLang.kn ? 'kn-IN' : 'en-IN';

  String get label => this == WeatherLang.kn ? 'ಕನ್ನಡ' : 'English';
}

/// All user-facing weather text, in English and Kannada. Keeping the strings
/// together (rather than inline) is what makes the language selector and the
/// read-aloud button consistent with the labels on screen.
class WeatherStrings {
  final WeatherLang lang;

  const WeatherStrings(this.lang);

  String _p(String key) {
    final table = lang == WeatherLang.kn ? _kn : _en;
    return table[key] ?? _en[key] ?? key;
  }

  String get appTitle => _p('appTitle');
  String get searchHint => _p('searchHint');
  String get noSuggestions => _p('noSuggestions');
  String get useMyLocation => _p('useMyLocation');
  String get currentLocation => _p('currentLocation');
  String get locationPermissionDenied => _p('locationPermissionDenied');
  String get locationPermissionForever => _p('locationPermissionForever');
  String get locationDisabled => _p('locationDisabled');
  String get locationError => _p('locationError');
  String get feelsLike => _p('feelsLike');
  String get humidity => _p('humidity');
  String get wind => _p('wind');
  String get visibility => _p('visibility');
  String get pressure => _p('pressure');
  String get rain => _p('rain');
  String get hourlyTitle => _p('hourlyTitle');
  String get now => _p('now');
  String get weeklyTitle => _p('weeklyTitle');
  String get airQuality => _p('airQuality');
  String get aqiUnavailable => _p('aqiUnavailableBody');
  String get alertsTitle => _p('alertsTitle');
  String get noAlerts => _p('noAlerts');
  String get whatToDo => _p('whatToDo');
  String get farmingTip => _p('farmingTip');
  String get listen => _p('listen');
  String get stop => _p('stop');
  String get retry => _p('retry');
  String get changePlace => _p('changePlace');
  String get weatherUnavailable => _p('weatherUnavailable');
  String get noLocationYet => _p('noLocationYet');
  String get chooseLocation => _p('chooseLocation');
  String get chooseLocationBody => _p('chooseLocationBody');
  String get loading => _p('loading');
  String get lastUpdated => _p('lastUpdated');
  String get unavailable => _p('unavailable');
  String get today => _p('today');
  String get language => _p('language');

  /// Human word for a weather bucket (Sunny / Cloudy / …).
  String condition(WeatherCategory category) {
    switch (category) {
      case WeatherCategory.sunny:
        return _p('condSunny');
      case WeatherCategory.cloudy:
        return _p('condCloudy');
      case WeatherCategory.rainy:
        return _p('condRainy');
      case WeatherCategory.stormy:
        return _p('condStormy');
      case WeatherCategory.snowy:
        return _p('condSnowy');
      case WeatherCategory.foggy:
        return _p('condFoggy');
      case WeatherCategory.other:
        return _p('condOther');
    }
  }

  /// Localized air-quality wording for the provider's English category.
  String airQualityCategory(String providerCategory) {
    final key = 'aqi$providerCategory';
    final table = lang == WeatherLang.kn ? _kn : _en;
    return table[key] ?? providerCategory;
  }

  /// The sentence read aloud and shown as the spoken summary.
  String speechSummary({
    required String place,
    required String condition,
    required int temp,
    required int feels,
    required int humidity,
    required int windKph,
    required int rainChance,
    required String advice,
  }) {
    if (lang == WeatherLang.kn) {
      return '$place ಗಾಗಿ ಹವಾಮಾನ. $condition. ಉಷ್ಣಾಂಶ $temp ಡಿಗ್ರಿ ಸೆಲ್ಸಿಯಸ್, '
          'ಅನುಭವ $feels. ತೇವಾಂಶ $humidity ಪ್ರತಿಶತ. ಗಾಳಿ $windKph ಕಿಲೋಮೀಟರ್ '
          'ಪ್ರತಿ ಗಂಟೆ. ಮಳೆಯ ಸಾಧ್ಯತೆ $rainChance ಪ್ರತಿಶತ. $advice';
    }
    return 'Weather for $place. $condition. Temperature $temp degrees Celsius, '
        'feels like $feels. Humidity $humidity percent. Wind $windKph '
        'kilometres per hour. Rain chance $rainChance percent. $advice';
  }

  static const Map<String, String> _en = {
    'appTitle': 'Weather',
    'searchHint': 'Search village, town, district or PIN',
    'noSuggestions': 'No matching places',
    'useMyLocation': 'Use my location',
    'currentLocation': 'Current location',
    'locationPermissionDenied':
        'Location permission denied. Search for your place instead.',
    'locationPermissionForever':
        'Location is blocked. Enable it in settings, or search for your place.',
    'locationDisabled':
        'Location services are off. Search for your place instead.',
    'locationError':
        'Could not get your location. Search for your place instead.',
    'feelsLike': 'Feels like',
    'humidity': 'Humidity',
    'wind': 'Wind',
    'visibility': 'Visibility',
    'pressure': 'Pressure',
    'rain': 'Rain',
    'hourlyTitle': "Today's hourly forecast",
    'now': 'Now',
    'weeklyTitle': 'Seven-day forecast',
    'airQuality': 'Air quality',
    'aqiUnavailableBody': 'Air quality data unavailable.',
    'alertsTitle': 'Weather alerts',
    'noAlerts': 'No weather alerts right now.',
    'whatToDo': 'What should I do?',
    'farmingTip': 'Farming tip',
    'listen': 'Listen',
    'stop': 'Stop',
    'retry': 'Retry',
    'changePlace': 'Change place',
    'weatherUnavailable': 'Weather unavailable',
    'noLocationYet': 'No location yet',
    'chooseLocation': 'Choose a location',
    'chooseLocationBody':
        'Choose a place to see live weather and farming guidance.',
    'loading': 'Loading…',
    'lastUpdated': 'Last updated',
    'unavailable': 'Unavailable',
    'today': 'Today',
    'language': 'Language',
    'condSunny': 'Sunny',
    'condCloudy': 'Cloudy',
    'condRainy': 'Rainy',
    'condStormy': 'Stormy',
    'condSnowy': 'Snowy',
    'condFoggy': 'Foggy',
    'condOther': 'Mixed',
    'aqiGood': 'Good',
    'aqiModerate': 'Moderate',
    'aqiUnhealthy for sensitive groups': 'Unhealthy for sensitive groups',
    'aqiUnhealthy': 'Unhealthy',
    'aqiVery unhealthy': 'Very unhealthy',
    'aqiHazardous': 'Hazardous',
    'aqiUnavailable': 'Unavailable',
  };

  static const Map<String, String> _kn = {
    'appTitle': 'ಹವಾಮಾನ',
    'searchHint': 'ಹಳ್ಳಿ, ಪಟ್ಟಣ, ಜಿಲ್ಲೆ ಅಥವಾ ಪಿನ್ ಹುಡುಕಿ',
    'noSuggestions': 'ಹೊಂದಿಕೆಯಾಗುವ ಸ್ಥಳಗಳಿಲ್ಲ',
    'useMyLocation': 'ನನ್ನ ಸ್ಥಳ ಬಳಸಿ',
    'currentLocation': 'ಪ್ರಸ್ತುತ ಸ್ಥಳ',
    'locationPermissionDenied': 'ಸ್ಥಳ ಅನುಮತಿ ನಿರಾಕರಿಸಲಾಗಿದೆ. ಬದಲಾಗಿ ಹುಡುಕಿ.',
    'locationPermissionForever':
        'ಸ್ಥಳ ನಿರ್ಬಂಧಿಸಲಾಗಿದೆ. ಸೆಟ್ಟಿಂಗ್ಸ್ನಲ್ಲಿ ಆನ್ ಮಾಡಿ ಅಥವಾ ಹುಡುಕಿ.',
    'locationDisabled': 'ಸ್ಥಳ ಸೇವೆಗಳು ಆಫ್ ಆಗಿವೆ. ಬದಲಾಗಿ ಹುಡುಕಿ.',
    'locationError': 'ನಿಮ್ಮ ಸ್ಥಳ ಸಿಗಲಿಲ್ಲ. ಬದಲಾಗಿ ಹುಡುಕಿ.',
    'feelsLike': 'ಅನುಭವ',
    'humidity': 'ತೇವಾಂಶ',
    'wind': 'ಗಾಳಿ',
    'visibility': 'ಗೋಚರತೆ',
    'pressure': 'ಒತ್ತಡ',
    'rain': 'ಮಳೆ',
    'hourlyTitle': 'ಇಂದಿನ ಪ್ರತಿ ಗಂಟೆಯ ಮುನ್ಸೂಚನೆ',
    'now': 'ಈಗ',
    'weeklyTitle': 'ಏಳು ದಿನಗಳ ಮುನ್ಸೂಚನೆ',
    'airQuality': 'ಗಾಳಿಯ ಗುಣಮಟ್ಟ',
    'aqiUnavailableBody': 'ಗಾಳಿಯ ಗುಣಮಟ್ಟದ ಮಾಹಿತಿ ಲಭ್ಯವಿಲ್ಲ.',
    'alertsTitle': 'ಹವಾಮಾನ ಎಚ್ಚರಿಕೆಗಳು',
    'noAlerts': 'ಸದ್ಯಕ್ಕೆ ಯಾವುದೇ ಹವಾಮಾನ ಎಚ್ಚರಿಕೆಗಳಿಲ್ಲ.',
    'whatToDo': 'ನಾನು ಏನು ಮಾಡಬೇಕು?',
    'farmingTip': 'ಕೃಷಿ ಸಲಹೆ',
    'listen': 'ಕೇಳಿ',
    'stop': 'ನಿಲ್ಲಿಸಿ',
    'retry': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    'changePlace': 'ಸ್ಥಳ ಬದಲಿಸಿ',
    'weatherUnavailable': 'ಹವಾಮಾನ ಲಭ್ಯವಿಲ್ಲ',
    'noLocationYet': 'ಇನ್ನೂ ಸ್ಥಳವಿಲ್ಲ',
    'chooseLocation': 'ಸ್ಥಳ ಆಯ್ಕೆಮಾಡಿ',
    'chooseLocationBody': 'ನೇರ ಹವಾಮಾನ ಮತ್ತು ಕೃಷಿ ಸಲಹೆಗಾಗಿ ಸ್ಥಳ ಆಯ್ಕೆಮಾಡಿ.',
    'loading': 'ಲೋಡ್ ಆಗುತ್ತಿದೆ…',
    'lastUpdated': 'ಕೊನೆಯ ನವೀಕರಣ',
    'unavailable': 'ಲಭ್ಯವಿಲ್ಲ',
    'today': 'ಇಂದು',
    'language': 'ಭಾಷೆ',
    'condSunny': 'ಬಿಸಿಲು',
    'condCloudy': 'ಮೋಡ',
    'condRainy': 'ಮಳೆ',
    'condStormy': 'ಬಿರುಗಾಳಿ',
    'condSnowy': 'ಹಿಮ',
    'condFoggy': 'ಮಂಜು',
    'condOther': 'ಮಿಶ್ರ',
    'aqiGood': 'ಉತ್ತಮ',
    'aqiModerate': 'ಮಧ್ಯಮ',
    'aqiUnhealthy for sensitive groups': 'ಸೂಕ್ಷ್ಮ ಗುಂಪಿಗೆ ಅನಾರೋಗ್ಯಕರ',
    'aqiUnhealthy': 'ಅನಾರೋಗ್ಯಕರ',
    'aqiVery unhealthy': 'ಬಹಳ ಅನಾರೋಗ್ಯಕರ',
    'aqiHazardous': 'ಅಪಾಯಕಾರಿ',
    'aqiUnavailable': 'ಲಭ್ಯವಿಲ್ಲ',
  };
}
