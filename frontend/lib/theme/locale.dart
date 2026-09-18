import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { english, kannada }

/// Lightweight English / Kannada localization for the app shell and key screens.
class LanguageController extends ChangeNotifier {
  LanguageController._();
  static final LanguageController instance = LanguageController._();

  static const _key = 'app_language';

  AppLang _lang = AppLang.english;
  AppLang get lang => _lang;
  bool get isKannada => _lang == AppLang.kannada;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString(_key) == 'kn' ? AppLang.kannada : AppLang.english;
    notifyListeners();
  }

  Future<void> setLang(AppLang lang) async {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang == AppLang.kannada ? 'kn' : 'en');
  }
}

/// Human-readable keys; translation dictionary held here.
class K {
  static const dashboard = 'dashboard';
  static const overview = 'overview';
  static const deals = 'deals';
  static const postOffer = 'postOffer';
  static const myCrops = 'myCrops';
  static const traders = 'traders';
  static const marketPrices = 'marketPrices';
  static const weather = 'weather';
  static const toolRental = 'toolRental';
  static const marketplace = 'marketplace';
  static const notifications = 'notifications';
  static const profile = 'profile';
  static const settings = 'settings';
  static const sellCrop = 'sellCrop';
  static const qualityAnalysis = 'qualityAnalysis';
  static const getStarted = 'getStarted';
  static const login = 'login';
  static const register = 'register';
  static const welcomeBack = 'welcomeBack';
  static const greetingMorning = 'greetingMorning';
  static const greetingAfternoon = 'greetingAfternoon';
  static const greetingEvening = 'greetingEvening';
  static const language = 'language';
  static const english = 'english';
  static const kannada = 'kannada';
  static const logOut = 'logOut';
  static const save = 'save';
  static const cancel = 'cancel';
  static const confirm = 'confirm';
  static const demoOtp = 'demoOtp';
  static const continueWithGoogle = 'continueWithGoogle';
  static const loginWithPhone = 'loginWithPhone';
  static const createAccount = 'createAccount';
  static const quickActions = 'quickActions';
  static const weatherSummary = 'weatherSummary';
  static const liveMarketPrices = 'liveMarketPrices';
  static const recentListings = 'recentListings';
  static const recentOffers = 'recentOffers';
  static const tipOfTheDay = 'tipOfTheDay';
  static const farmOverview = 'farmOverview';
  static const allGood = 'allGood';
  static const noData = 'noData';
  static const tryAgain = 'tryAgain';
  static const search = 'search';
  static const today = 'today';
  static const thisWeek = 'thisWeek';
}

class AppStrings {
  static const _en = <String, String>{
    K.dashboard: 'Dashboard',
    K.overview: 'Overview',
    K.deals: 'Deals',
    K.postOffer: 'Post Offer',
    K.myCrops: 'My Crops',
    K.traders: 'Traders',
    K.marketPrices: 'Market Prices',
    K.weather: 'Weather',
    K.toolRental: 'Tool Rental',
    K.marketplace: 'Marketplace',
    K.notifications: 'Notifications',
    K.profile: 'Profile',
    K.settings: 'Settings',
    K.sellCrop: 'Sell Crop',
    K.qualityAnalysis: 'Quality Analysis',
    K.getStarted: 'Get Started',
    K.login: 'Login',
    K.register: 'Register',
    K.welcomeBack: 'Welcome back',
    K.greetingMorning: 'Good morning',
    K.greetingAfternoon: 'Good afternoon',
    K.greetingEvening: 'Good evening',
    K.language: 'Language',
    K.english: 'English',
    K.kannada: 'Kannada',
    K.logOut: 'Log Out',
    K.save: 'Save',
    K.cancel: 'Cancel',
    K.confirm: 'Confirm',
    K.demoOtp: 'Demo OTP: 1234',
    K.continueWithGoogle: 'Continue with Google',
    K.loginWithPhone: 'Login with Phone (OTP)',
    K.createAccount: 'Create Account',
    K.quickActions: 'Quick Actions',
    K.weatherSummary: 'Weather Summary',
    K.liveMarketPrices: 'Live Market Prices',
    K.recentListings: 'Recent Crop Listings',
    K.recentOffers: 'Recent Trader Offers',
    K.tipOfTheDay: 'Farming Tip of the Day',
    K.farmOverview: 'Farm Overview',
    K.allGood: 'All systems look good',
    K.noData: 'Nothing here yet',
    K.tryAgain: 'Try Again',
    K.search: 'Search',
    K.today: 'Today',
    K.thisWeek: 'This week',
  };

  static const _kn = <String, String>{
    K.dashboard: 'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
    K.overview: 'ಅವಲೋಕನ',
    K.deals: 'ವ್ಯವಹಾರಗಳು',
    K.postOffer: 'ಕೊಡುಗೆ ನೀಡಿ',
    K.myCrops: 'ನನ್ನ ಬೆಳೆಗಳು',
    K.traders: 'ವ್ಯಾಪಾರಿಗಳು',
    K.marketPrices: 'ಮಾರುಕಟ್ಟೆ ದರಗಳು',
    K.weather: 'ಹವಾಮಾನ',
    K.toolRental: 'ಸಲಕರಣೆ ಬಾಡಿಗೆ',
    K.marketplace: 'ಮಾರುಕಟ್ಟೆ',
    K.notifications: 'ಅಧಿಸೂಚನೆಗಳು',
    K.profile: 'ಪ್ರೊಫೈಲ್',
    K.settings: 'ಸೆಟಿಂಗ್‌ಗಳು',
    K.sellCrop: 'ಬೆಳೆ ಮಾರಾಟ',
    K.qualityAnalysis: 'ಗುಣಮಟ್ಟ ವಿಶ್ಲೇಷಣೆ',
    K.getStarted: 'ಪ್ರಾರಂಭಿಸಿ',
    K.login: 'ಲಾಗಿನ್',
    K.register: 'ನೋಂದಣಿ',
    K.welcomeBack: 'ಮರಳಿ ಸ್ವಾಗತ',
    K.greetingMorning: 'ಶುಭೋದಯ',
    K.greetingAfternoon: 'ಶುಭ ಮಧ್ಯಾಹ್ನ',
    K.greetingEvening: 'ಶುಭ ಸಂಜೆ',
    K.language: 'ಭಾಷೆ',
    K.english: 'ಇಂಗ್ಲಿಷ್',
    K.kannada: 'ಕನ್ನಡ',
    K.logOut: 'ಲಾಗ್ ಔಟ್',
    K.save: 'ಉಳಿಸಿ',
    K.cancel: 'ರದ್ದು',
    K.confirm: 'ದೃಢೀಕರಿಸಿ',
    K.demoOtp: 'ಡೆಮೊ OTP: 1234',
    K.continueWithGoogle: 'ಗೂಗಲ್ ಮೂಲಕ ಮುಂದುವರಿಸಿ',
    K.loginWithPhone: 'ಫೋನ್ (OTP) ಮೂಲಕ ಲಾಗಿನ್',
    K.createAccount: 'ಖಾತೆ ರಚಿಸಿ',
    K.quickActions: 'ತ್ವರಿತ ಕ್ರಿಯೆಗಳು',
    K.weatherSummary: 'ಹವಾಮಾನ ಸಾರಾಂಶ',
    K.liveMarketPrices: 'ಲೈವ್ ಮಾರುಕಟ್ಟೆ ದರಗಳು',
    K.recentListings: 'ಇತ್ತೀಚಿನ ಬೆಳೆ ಪಟ್ಟಿಗಳು',
    K.recentOffers: 'ಇತ್ತೀಚಿನ ವ್ಯಾಪಾರಿ ಕೊಡುಗೆಗಳು',
    K.tipOfTheDay: 'ಇಂದಿನ ಕೃಷಿ ಸಲಹೆ',
    K.farmOverview: 'ಕೃಷಿ ಅವಲೋಕನ',
    K.allGood: 'ಎಲ್ಲವೂ ಸರಿಯಾಗಿದೆ',
    K.noData: 'ಇನ್ನೂ ಏನೂ ಇಲ್ಲ',
    K.tryAgain: 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    K.search: 'ಹುಡುಕಿ',
    K.today: 'ಇಂದು',
    K.thisWeek: 'ಈ ವಾರ',
  };

  /// Returns localized string. Falls back to English.
  static String of(BuildContext context, String key, {String? fallback}) {
    final map = LanguageController.instance.isKannada ? _kn : _en;
    return map[key] ?? fallback ?? key;
  }
}

extension AppStringsX on BuildContext {
  String str(String key, {String? fallback}) => AppStrings.of(this, key, fallback: fallback);
}