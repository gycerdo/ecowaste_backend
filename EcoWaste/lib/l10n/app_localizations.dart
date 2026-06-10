import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('en'),
    Locale('sw'),
  ];

  static const Map<String, Map<String, String>> _strings = {
    // ── General ──────────────────────────────────────────────────────────────
    'app_name': {'en': 'EcoWaste', 'sw': 'EcoTaka'},
    'ok': {'en': 'OK', 'sw': 'Sawa'},
    'cancel': {'en': 'Cancel', 'sw': 'Ghairi'},
    'retry': {'en': 'Retry', 'sw': 'Jaribu tena'},
    'save': {'en': 'Save', 'sw': 'Hifadhi'},
    'close': {'en': 'Close', 'sw': 'Funga'},
    'error': {'en': 'Error', 'sw': 'Hitilafu'},
    'loading': {'en': 'Loading...', 'sw': 'Inapakia...'},
    'search': {'en': 'Search...', 'sw': 'Tafuta...'},
    'see_all': {'en': 'See All', 'sw': 'Tazama Zote'},

    // ── Auth ─────────────────────────────────────────────────────────────────
    'login': {'en': 'Log In', 'sw': 'Ingia'},
    'logout': {'en': 'Log Out', 'sw': 'Toka'},
    'logout_confirm': {
      'en': 'Are you sure you want to log out?',
      'sw': 'Una uhakika unataka kutoka?'
    },
    'register': {'en': 'Register', 'sw': 'Jisajili'},
    'username': {'en': 'Username', 'sw': 'Jina la mtumiaji'},
    'password': {'en': 'Password', 'sw': 'Nenosiri'},
    'email': {'en': 'Email', 'sw': 'Barua pepe'},
    'full_name': {'en': 'Full Name', 'sw': 'Jina kamili'},
    'phone': {'en': 'Phone', 'sw': 'Simu'},
    'driver_license': {'en': 'Driver License', 'sw': 'Leseni ya udereva'},
    'forgot_password': {'en': 'Forgot password?', 'sw': 'Umesahau nenosiri?'},
    'no_account': {'en': "Don't have an account?", 'sw': 'Huna akaunti?'},
    'have_account': {
      'en': 'Already have an account?',
      'sw': 'Una akaunti tayari?'
    },

    // ── Navigation ────────────────────────────────────────────────────────────
    'nav_home': {'en': 'Home', 'sw': 'Nyumbani'},
    'nav_map': {'en': 'Map', 'sw': 'Ramani'},
    'nav_log': {'en': 'Log Waste', 'sw': 'Rekodi Taka'},
    'nav_stats': {'en': 'Stats', 'sw': 'Takwimu'},
    'nav_profile': {'en': 'Profile', 'sw': 'Wasifu'},

    // ── Map screen ────────────────────────────────────────────────────────────
    'map_title': {'en': 'EcoWaste Map', 'sw': 'Ramani ya EcoTaka'},
    'search_points': {
      'en': 'Search collection points...',
      'sw': 'Tafuta maeneo ya ukusanyaji...'
    },
    'filter_all': {'en': 'All', 'sw': 'Zote'},
    'filter_general': {'en': 'General', 'sw': 'Kawaida'},
    'filter_recycling': {'en': 'Recycling', 'sw': 'Kuchakata'},
    'filter_hazardous': {'en': 'Hazardous', 'sw': 'Hatari'},
    'no_points': {
      'en': 'No locations found',
      'sw': 'Hakuna maeneo yaliyopatikana'
    },
    'no_search_results': {'en': 'No results for', 'sw': 'Hakuna matokeo kwa'},
    'nearby_vehicles': {'en': 'Nearby Vehicles', 'sw': 'Magari Karibu'},
    'recycling_centers': {
      'en': 'Recycling Centers',
      'sw': 'Vituo vya Kuchakata'
    },
    'km_away': {'en': 'km away', 'sw': 'km mbali'},

    // ── Profile screen ────────────────────────────────────────────────────────
    'profile': {'en': 'Profile', 'sw': 'Wasifu'},
    'eco_points': {'en': 'Eco Points', 'sw': 'Pointi za Mazingira'},
    'collected': {'en': 'Collected', 'sw': 'Zilizokusanywa'},
    'account_details': {'en': 'Account Details', 'sw': 'Maelezo ya Akaunti'},
    'level_bronze': {'en': 'Bronze Member', 'sw': 'Mwanachama wa Shaba'},
    'level_silver': {'en': 'Silver Member', 'sw': 'Mwanachama wa Fedha'},
    'level_gold': {'en': 'Gold Member', 'sw': 'Mwanachama wa Dhahabu'},
    'level_platinum': {
      'en': 'Platinum Member',
      'sw': 'Mwanachama wa Platinamu'
    },
    'max_level': {'en': '🎉 Max level!', 'sw': '🎉 Kiwango cha juu!'},
    'points_to_next': {
      'en': 'more points to next level',
      'sw': 'pointi zaidi kwa kiwango kinachofuata'
    },
    'could_not_load': {
      'en': 'Could not load profile',
      'sw': 'Imeshindwa kupakia wasifu'
    },

    // ── Settings screen ───────────────────────────────────────────────────────
    'settings': {'en': 'Settings', 'sw': 'Mipangilio'},
    'appearance': {'en': 'Appearance', 'sw': 'Mwonekano'},
    'dark_mode': {'en': 'Dark Mode', 'sw': 'Hali ya Giza'},
    'dark_mode_sub': {
      'en': 'Switch between light and dark theme',
      'sw': 'Badilisha kati ya mwanga na giza'
    },
    'language': {'en': 'Language', 'sw': 'Lugha'},
    'language_sub': {
      'en': 'Choose your preferred language',
      'sw': 'Chagua lugha unayopendelea'
    },
    'lang_english': {'en': 'English', 'sw': 'Kiingereza'},
    'lang_swahili': {'en': 'Swahili', 'sw': 'Kiswahili'},
    'about': {'en': 'About', 'sw': 'Kuhusu'},
    'version': {'en': 'Version', 'sw': 'Toleo'},
    'app_description': {
      'en': 'Civic waste intelligence platform',
      'sw': 'Jukwaa la akili ya taka za kiraia'
    },

    // ── Greetings ─────────────────────────────────────────────────────────────
    'good_morning': {'en': 'Good Morning!', 'sw': 'Habari za Asubuhi!'},
    'good_afternoon': {'en': 'Good Afternoon!', 'sw': 'Habari za Mchana!'},
    'good_evening': {'en': 'Good Evening!', 'sw': 'Habari za Jioni!'},

    // ── Log waste ─────────────────────────────────────────────────────────────
    'log_waste': {'en': 'Log Waste', 'sw': 'Rekodi Taka'},
    'waste_type': {'en': 'Waste Type', 'sw': 'Aina ya Taka'},
    'weight_kg': {'en': 'Weight (kg)', 'sw': 'Uzito (kg)'},
    'submit': {'en': 'Submit', 'sw': 'Wasilisha'},
    'submitted': {'en': 'Submitted!', 'sw': 'Imewasilishwa!'},

    // ── Verification / AI Scan ────────────────────────────────────────────────
    'ai_waste_scan': {'en': 'AI Waste Scan', 'sw': 'Skana Taka kwa AI'},
    'scan_camera': {'en': 'Camera', 'sw': 'Kamera'},
    'scan_gallery': {'en': 'Gallery', 'sw': 'Picha'},
    'scan_rescan': {'en': 'Re-scan', 'sw': 'Skana Tena'},
    'scan_placeholder': {
      'en': 'Point camera at waste',
      'sw': 'Elekeza kamera kwenye taka'
    },
    'scan_placeholder_sub': {
      'en': 'AI will identify waste type instantly',
      'sw': 'AI itatambua aina ya taka mara moja'
    },
    'scan_analysing': {
      'en': 'AI Analysing Waste...',
      'sw': 'AI Inachambua Taka...'
    },
    'scan_detected': {'en': 'DETECTED', 'sw': 'IMEPATIKANA'},
    'scan_result_title': {'en': 'AI Detection Result', 'sw': 'Matokeo ya AI'},
    'scan_confidence': {'en': 'AI Confidence', 'sw': 'Uhakika wa AI'},
    'scan_confirm_log': {
      'en': 'Confirm & Log Waste Entry',
      'sw': 'Thibitisha & Rekodi Taka'
    },
    'scan_skip_manual': {
      'en': 'Skip — Manual Entry',
      'sw': 'Ruka — Ingiza Mwenyewe'
    },
    'scan_cta': {'en': 'Scan Waste with AI', 'sw': 'Skana Taka kwa AI'},
    'scan_info': {
      'en':
          'Ensure waste is clearly visible in frame. If quota error appears, check your key at aistudio.google.com',
      'sw':
          'Hakikisha taka inaonekana wazi. Kama kuna hitilafu ya kikomo, angalia funguo yako kwenye aistudio.google.com'
    },

    // ── Nearby Centers ────────────────────────────────────────────────────────
    'recycling_centers_title': {
      'en': 'Recycling Centers',
      'sw': 'Vituo vya Kuchakata'
    },
    'no_centers': {
      'en': 'No centers found',
      'sw': 'Hakuna vituo vilivyopatikana'
    },
    'accepts': {'en': 'Accepts:', 'sw': 'Inakubali:'},
    'book_slot': {'en': 'Book a Slot', 'sw': 'Weka Nafasi'},
    'select_date': {'en': 'Select Date', 'sw': 'Chagua Tarehe'},
    'select_time_slot': {'en': 'Select Time Slot', 'sw': 'Chagua Wakati'},
    'confirm_booking': {'en': 'Confirm Booking', 'sw': 'Thibitisha Nafasi'},
    'select_date_time': {
      'en': 'Please select date and time',
      'sw': 'Tafadhali chagua tarehe na wakati'
    },

    // ── Stats ─────────────────────────────────────────────────────────────────
    'stats': {'en': 'Statistics', 'sw': 'Takwimu'},
    'my_stats': {'en': 'My Stats', 'sw': 'Takwimu Zangu'},
    'leaderboard': {'en': 'Leaderboard', 'sw': 'Orodha ya Washindi'},
    'total_waste': {'en': 'Total Waste', 'sw': 'Jumla ya Taka'},
    'total_trips': {'en': 'Total Trips', 'sw': 'Jumla ya Safari'},
    'this_month': {'en': 'This Month', 'sw': 'Mwezi Huu'},
    'this_week': {'en': 'This Week', 'sw': 'Wiki Hii'},
    'kg_collected': {'en': 'Kg Collected', 'sw': 'Kg Zilizokusanywa'},
    'trips_made': {'en': 'Trips Made', 'sw': 'Safari Zilizofanywa'},
    'trips': {'en': 'trips', 'sw': 'safari'},
    'current_rank': {'en': 'Current Rank', 'sw': 'Nafasi ya Sasa'},
    'achievements': {'en': 'Achievements', 'sw': 'Mafanikio'},
    'first_log': {'en': 'First Log', 'sw': 'Rekodi ya Kwanza'},
    'ten_trips': {'en': '10 Trips', 'sw': 'Safari 10'},
    'hundred_kg': {'en': '100 kg', 'sw': 'Kg 100'},
    'eco_star': {'en': 'Eco Star', 'sw': 'Nyota ya Mazingira'},
    'no_leaderboard': {
      'en': 'No leaderboard data yet',
      'sw': 'Hakuna data ya orodha bado'
    },
  };

  String get(String key) {
    final lang = locale.languageCode;
    return _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
  }

  // ── Convenience getters ───────────────────────────────────────────────────
  String get appName => get('app_name');
  String get ok => get('ok');
  String get cancel => get('cancel');
  String get retry => get('retry');
  String get save => get('save');
  String get search => get('search');
  String get loading => get('loading');
  String get login => get('login');
  String get logout => get('logout');
  String get logoutConfirm => get('logout_confirm');
  String get register => get('register');
  String get username => get('username');
  String get password => get('password');
  String get email => get('email');
  String get fullName => get('full_name');
  String get phone => get('phone');
  String get driverLicense => get('driver_license');
  String get navHome => get('nav_home');
  String get navMap => get('nav_map');
  String get navLog => get('nav_log');
  String get navStats => get('nav_stats');
  String get navProfile => get('nav_profile');
  String get mapTitle => get('map_title');
  String get searchPoints => get('search_points');
  String get filterAll => get('filter_all');
  String get filterGeneral => get('filter_general');
  String get filterRecycling => get('filter_recycling');
  String get filterHazardous => get('filter_hazardous');
  String get noPoints => get('no_points');
  String get noSearchResults => get('no_search_results');
  String get nearbyVehicles => get('nearby_vehicles');
  String get recyclingCenters => get('recycling_centers');
  String get kmAway => get('km_away');
  String get profile => get('profile');
  String get ecoPoints => get('eco_points');
  String get collected => get('collected');
  String get accountDetails => get('account_details');
  String get maxLevel => get('max_level');
  String get pointsToNext => get('points_to_next');
  String get couldNotLoad => get('could_not_load');
  String get settings => get('settings');
  String get appearance => get('appearance');
  String get darkMode => get('dark_mode');
  String get darkModeSub => get('dark_mode_sub');
  String get language => get('language');
  String get languageSub => get('language_sub');
  String get langEnglish => get('lang_english');
  String get langSwahili => get('lang_swahili');
  String get about => get('about');
  String get version => get('version');
  String get logWaste => get('log_waste');
  String get stats => get('stats');
  String get totalWaste => get('total_waste');
  String get thisMonth => get('this_month');
  String get thisWeek => get('this_week');
  String get recyclingCentersTitle => get('recycling_centers_title');
  String get noCenters => get('no_centers');
  String get accepts => get('accepts');
  String get bookSlot => get('book_slot');
  String get selectDate => get('select_date');
  String get selectTimeSlot => get('select_time_slot');
  String get confirmBooking => get('confirm_booking');
  String get selectDateTime => get('select_date_time');
  String get aiWasteScan => get('ai_waste_scan');
  String get scanCamera => get('scan_camera');
  String get scanGallery => get('scan_gallery');
  String get scanRescan => get('scan_rescan');
  String get scanPlaceholder => get('scan_placeholder');
  String get scanPlaceholderSub => get('scan_placeholder_sub');
  String get scanAnalysing => get('scan_analysing');
  String get scanDetected => get('scan_detected');
  String get scanResultTitle => get('scan_result_title');
  String get scanConfidence => get('scan_confidence');
  String get scanConfirmLog => get('scan_confirm_log');
  String get scanSkipManual => get('scan_skip_manual');
  String get scanCta => get('scan_cta');
  String get scanInfo => get('scan_info');

  // ── Greeting — uses LOCAL device time (fixes UTC issue) ───────────────────
  String greeting() {
    final h = DateTime.now().toLocal().hour; // ← toLocal() reads Tanzania time
    if (h < 12) return get('good_morning');
    if (h < 17) return get('good_afternoon');
    return get('good_evening');
  }

  String levelName(int points) {
    if (points >= 1000) return get('level_platinum');
    if (points >= 500) return get('level_gold');
    if (points >= 200) return get('level_silver');
    return get('level_bronze');
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'sw'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
