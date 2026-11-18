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

  // Assistant + navigation
  static const chat = 'chat';
  static const groupAssistant = 'groupAssistant';
  static const groupTools = 'groupTools';
  static const groupMarketplace = 'groupMarketplace';
  static const groupAccount = 'groupAccount';
  static const newConversation = 'newConversation';
  static const switchTheme = 'switchTheme';
  static const searchTools = 'searchTools';

  // Market prices + provenance
  static const searchCrops = 'searchCrops';
  static const filterFreshness = 'filterFreshness';
  static const all = 'all';
  static const fresh = 'fresh';
  static const stale = 'stale';
  static const noMarketData = 'noMarketData';
  static const noMarketDataHint = 'noMarketDataHint';
  static const noCropsFound = 'noCropsFound';
  static const noCropsFoundHint = 'noCropsFoundHint';
  static const marketDataUnavailable = 'marketDataUnavailable';
  static const tooOldToAct = 'tooOldToAct';
  static const tooOldToActHint = 'tooOldToActHint';
  static const staleWindowHint = 'staleWindowHint';
  static const confirmWithMandi = 'confirmWithMandi';
  static const daysOld = 'daysOld'; // {n} day(s) old
  static const observedDaysAgo = 'observedDaysAgo'; // {d} ({n} day(s) ago)
  static const observedToday = 'observedToday'; // {d} (today)
  static const undatedObservation = 'undatedObservation';
  static const priceNotReported = 'priceNotReported';
  static const rangeSuffix = 'rangeSuffix'; // "range"
  static const arrivalsLabel = 'arrivalsLabel'; // Arrivals: {n}
  static const mandiNotReported = 'mandiNotReported';
  static const liveMarketData = 'liveMarketData';
  static const storedRatesOnly = 'storedRatesOnly';
  static const feedCountOff = 'feedCountOff'; // {n} feed(s) off
  static const serving = 'serving';
  static const notServing = 'notServing';
  static const dataSources = 'dataSources';
  static const checkedAt = 'checkedAt'; // checked {t}
  static const checkedJustNow = 'checkedJustNow';
  static const ageUnknown = 'ageUnknown';
  static const unverifiedFeed = 'unverifiedFeed';
  static const tryAgainNow = 'tryAgainNow';
  static const pricesUnavailableRightNow = 'pricesUnavailableRightNow';
  static const noOffersYet = 'noOffersYet';
  static const noOffersYetHint = 'noOffersYetHint';
  static const noRowsForCrop = 'noRowsForCrop';
  static const noQuotationsYet = 'noQuotationsYet';
  static const oldestRateDays = 'oldestRateDays'; // {n} day(s) old
  static const someRatesOld = 'someRatesOld';
  static const feedNeverVerified = 'feedNeverVerified';
  static const ageOfRatesUnknown = 'ageOfRatesUnknown';

  // Provenance tiers (letter stays the same in both languages)
  static const tierA = 'tierA';
  static const tierB = 'tierB';
  static const tierC = 'tierC';
  static const tierD = 'tierD';
  static const tierUnknown = 'tierUnknown';
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
    K.chat: 'Chat',
    K.groupAssistant: 'Assistant',
    K.groupTools: 'Assistant tools',
    K.groupMarketplace: 'Marketplace',
    K.groupAccount: 'Account',
    K.newConversation: 'New conversation',
    K.switchTheme: 'Switch theme',
    K.searchTools: 'Search tools',
    K.searchCrops: 'Search crops',
    K.filterFreshness: 'Filter by freshness',
    K.all: 'All',
    K.fresh: 'Fresh',
    K.stale: 'Stale',
    K.noMarketData: 'No market data',
    K.noMarketDataHint:
        'No rows are stored for this crop yet. Nothing is shown here until a source reports one.',
    K.noCropsFound: 'No crops found',
    K.noCropsFoundHint: 'Try a different search or filter.',
    K.marketDataUnavailable: 'Market data unavailable',
    K.tooOldToAct: 'Too old to act on',
    K.tooOldToActHint:
        'do not sell against this rate without confirming with the mandi.',
    K.staleWindowHint:
        'Rates older than a day may no longer be what buyers are paying. Confirm with the mandi before you sell.',
    K.confirmWithMandi: 'Confirm with the mandi before you sell.',
    K.daysOld: '{n} day(s) old',
    K.observedDaysAgo: '{d} ({n} day(s) ago)',
    K.observedToday: '{d} (today)',
    K.undatedObservation: 'Undated observation',
    K.priceNotReported: 'Price not reported',
    K.rangeSuffix: 'range',
    K.arrivalsLabel: 'Arrivals: {n}',
    K.mandiNotReported: 'Mandi not reported',
    K.liveMarketData: 'Live market data',
    K.storedRatesOnly: 'Stored rates only - no fresh pull',
    K.feedCountOff: '{n} feed(s) off',
    K.serving: 'serving',
    K.notServing: 'not serving',
    K.dataSources: 'Data sources',
    K.checkedAt: 'checked {t}',
    K.checkedJustNow: 'checked just now',
    K.ageUnknown: 'Age unknown',
    K.unverifiedFeed: 'Unverified feed',
    K.tryAgainNow: 'Try again',
    K.pricesUnavailableRightNow:
        'Market prices unavailable right now. Open Market Prices for the reason.',
    K.noOffersYet: 'No offers yet',
    K.noOffersYetHint: 'Offers from traders will appear here once they arrive.',
    K.tierA: 'official statistics',
    K.tierB: 'first-party',
    K.tierC: 'third-party feed',
    K.tierD: 'derived estimate',
    K.tierUnknown: 'unknown provenance',
    K.noRowsForCrop: 'No rows to show for the selected crop.',
    K.noQuotationsYet:
        'No mandi quotations stored yet. Nothing is shown until a source reports a price.',
    K.oldestRateDays: 'Oldest rate is {n} day(s) old',
    K.someRatesOld: 'Some rates are older than a day',
    K.feedNeverVerified: 'A feed here has never been verified',
    K.ageOfRatesUnknown: 'Age of these rates is unknown',
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
    K.chat: 'ಚಾಟ್',
    K.groupAssistant: 'ಸಹಾಯಕ',
    K.groupTools: 'ಸಹಾಯಕ ಸಲಕರಣೆಗಳು',
    K.groupMarketplace: 'ಮಾರುಕಟ್ಟೆ',
    K.groupAccount: 'ಖಾತೆ',
    K.newConversation: 'ಹೊಸ ಸಂಭಾಷಣೆ',
    K.switchTheme: 'ಥೀಮ್ ಬದಲಾಯಿಸಿ',
    K.searchTools: 'ಸಲಕರಣೆಗಳನ್ನು ಹುಡುಕಿ',
    K.searchCrops: 'ಬೆಳೆಗಳನ್ನು ಹುಡುಕಿ',
    K.filterFreshness: 'ಹೊಸತನದ ಆಧಾರದ ಮೇಲೆ ಶೋಧಿಸಿ',
    K.all: 'ಎಲ್ಲಾ',
    K.fresh: 'ಹೊಸದು',
    K.stale: 'ಹಳೆಯದು',
    K.noMarketData: 'ಮಾರುಕಟ್ಟೆ ದತ್ತಾಂಶ ಇಲ್ಲ',
    K.noMarketDataHint:
        'ಈ ಬೆಳೆಗೆ ಇನ್ನೂ ಯಾವುದೇ ದಾಖಲೆ ಇಲ್ಲ. ಮೂಲ ಒಂದು ದರ ನೀಡುವವರೆಗೆ ಇಲ್ಲಿ ಏನೂ ತೋರಿಸಲಾಗುವುದಿಲ್ಲ.',
    K.noCropsFound: 'ಬೆಳೆಗಳು ಸಿಗಲಿಲ್ಲ',
    K.noCropsFoundHint: 'ಬೇರೆ ಹುಡುಕಾಟ ಅಥವಾ ಶೋಧ ಪ್ರಯತ್ನಿಸಿ.',
    K.marketDataUnavailable: 'ಮಾರುಕಟ್ಟೆ ದತ್ತಾಂಶ ಲಭ್ಯವಿಲ್ಲ',
    K.tooOldToAct: 'ಕ್ರಮ ತೆಗೆದುಕೊಳ್ಳಲು ತುಂಬಾ ಹಳೆಯದು',
    K.tooOldToActHint:
        'ಮಾರುಕಟ್ಟೆಯಲ್ಲಿ ದೃಢಪಡಿಸದೆ ಈ ದರದ ಆಧಾರದ ಮೇಲೆ ಮಾರಬೇಡಿ.',
    K.staleWindowHint:
        'ಒಂದು ದಿನಕ್ಕಿಂತ ಹಳೆಯ ದರಗಳು ಈಗ ಖರೀದಿದಾರರು ನೀಡುತ್ತಿರುವ ಬೆಲೆ ಆಗಿರದಿರಬಹುದು. ಮಾರುವ ಮೊದಲು ಮಾರುಕಟ್ಟೆಯಲ್ಲಿ ದೃಢಪಡಿಸಿ.',
    K.confirmWithMandi: 'ಮಾರುವ ಮೊದಲು ಮಾರುಕಟ್ಟೆಯಲ್ಲಿ ದೃಢಪಡಿಸಿ.',
    K.daysOld: '{n} ದಿನ(ಗಳು) ಹಳೆಯದು',
    K.observedDaysAgo: '{d} ({n} ದಿನ(ಗಳ) ಹಿಂದೆ)',
    K.observedToday: '{d} (ಇಂದು)',
    K.undatedObservation: 'ದಿನಾಂಕ ಇಲ್ಲದ ದಾಖಲೆ',
    K.priceNotReported: 'ದರ ವರದಿಯಾಗಿಲ್ಲ',
    K.rangeSuffix: 'ವ್ಯಾಪ್ತಿ',
    K.arrivalsLabel: 'ಆಗಮನ: {n}',
    K.mandiNotReported: 'ಮಾರುಕಟ್ಟೆ ವರದಿಯಾಗಿಲ್ಲ',
    K.liveMarketData: 'ಲೈವ್ ಮಾರುಕಟ್ಟೆ ದತ್ತಾಂಶ',
    K.storedRatesOnly: 'ಸಂಗ್ರಹಿತ ದರಗಳು ಮಾತ್ರ - ಹೊಸ ದತ್ತಾಂಶ ಇಲ್ಲ',
    K.feedCountOff: '{n} ಮೂಲ(ಗಳು) ಕೆಲಸ ಮಾಡುತ್ತಿಲ್ಲ',
    K.serving: 'ಲಭ್ಯ',
    K.notServing: 'ಲಭ್ಯವಿಲ್ಲ',
    K.dataSources: 'ದತ್ತಾಂಶ ಮೂಲಗಳು',
    K.checkedAt: 'ಪರಿಶೀಲಿಸಲಾಗಿದೆ {t}',
    K.checkedJustNow: 'ಈಗಷ್ಟೇ ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
    K.ageUnknown: 'ವಯಸ್ಸು ಗೊತ್ತಿಲ್ಲ',
    K.unverifiedFeed: 'ಪರಿಶೀಲನೆಯಾಗದ ಮೂಲ',
    K.tryAgainNow: 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    K.pricesUnavailableRightNow:
        'ಈಗ ಮಾರುಕಟ್ಟೆ ದರಗಳು ಲಭ್ಯವಿಲ್ಲ. ಕಾರಣಕ್ಕಾಗಿ ಮಾರುಕಟ್ಟೆ ದರಗಳನ್ನು ತೆರೆಯಿರಿ.',
    K.noOffersYet: 'ಇನ್ನೂ ಕೊಡುಗೆಗಳಿಲ್ಲ',
    K.noOffersYetHint:
        'ವ್ಯಾಪಾರಿಗಳ ಕೊಡುಗೆಗಳು ಬಂದ ನಂತರ ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.',
    K.tierA: 'ಅಧಿಕೃತ ಅಂಕಿಅಂಶ',
    K.tierB: 'ಸ್ವಂತ ಮೂಲ',
    K.tierC: 'ಮೂರನೇ ಪಕ್ಷದ ಮೂಲ',
    K.tierD: 'ಲೆಕ್ಕಹಾಕಿದ ಅಂದಾಜು',
    K.tierUnknown: 'ಗೊತ್ತಿಲ್ಲದ ಮೂಲ',
    K.noRowsForCrop: 'ಆಯ್ಕೆ ಮಾಡಿದ ಬೆಳೆಗೆ ತೋರಿಸಲು ಯಾವುದೇ ದಾಖಲೆ ಇಲ್ಲ.',
    K.noQuotationsYet:
        'ಇನ್ನೂ ಯಾವುದೇ ಮಾರುಕಟ್ಟೆ ದರ ಸಂಗ್ರಹವಾಗಿಲ್ಲ. ಮೂಲ ಒಂದು ದರ ವರದಿ ಮಾಡುವವರೆಗೆ ಇಲ್ಲಿ ಏನೂ ತೋರಿಸಲಾಗುವುದಿಲ್ಲ.',
    K.oldestRateDays: 'ಹಳೆಯ ದರ {n} ದಿನ(ಗಳು) ಹಳೆಯದು',
    K.someRatesOld: 'ಕೆಲ ದರಗಳು ಒಂದು ದಿನಕ್ಕಿಂತ ಹಳೆಯದು',
    K.feedNeverVerified: 'ಇಲ್ಲಿನ ಒಂದು ಮೂಲವು ಇದುವರೆಗೆ ಪರಿಶೀಲನೆಯಾಗಿಲ್ಲ',
    K.ageOfRatesUnknown: 'ಈ ದರಗಳ ವಯಸ್ಸು ಗೊತ್ತಿಲ್ಲ',
  };

  /// Returns localized string. Falls back to English.
  static String of(BuildContext context, String key, {String? fallback}) {
    final map = LanguageController.instance.isKannada ? _kn : _en;
    return map[key] ?? fallback ?? key;
  }

  /// English lookup with no [BuildContext], for formatters that live outside
  /// the widget tree (models). Falls back to the key itself.
  static String enOf(String key) => _en[key] ?? key;
}

extension AppStringsX on BuildContext {
  String str(String key, {String? fallback}) =>
      AppStrings.of(this, key, fallback: fallback);
}
