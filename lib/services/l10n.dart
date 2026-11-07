import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language. English is the default. Hindi covers the main screens
/// (navigation, Home, Settings, Profile headings, tour). Anything not in the
/// table stays in English, so the app is never blank.
class AppLang extends ChangeNotifier {
  AppLang._();
  static final instance = AppLang._();

  bool hindi = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      hindi = p.getString('lang') == 'hi';
    } catch (_) {}
  }

  Future<void> set(bool hi) async {
    hindi = hi;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', hi ? 'hi' : 'en');
    } catch (_) {}
  }
}

/// Translates a screen text. Use for fixed English strings.
String tr(String s) => AppLang.instance.hindi ? (_hi[s] ?? s) : s;

const _hi = <String, String>{
  // navigation and quick add
  'Home': 'होम',
  'Diary': 'डायरी',
  'Workout': 'वर्कआउट',
  'Analytics': 'एनालिटिक्स',
  'Quick add': 'जल्दी जोड़ें',
  'Add': 'जोड़ें',
  'Food': 'खाना',
  'Scan': 'स्कैन',
  'Voice': 'आवाज़',
  'Meal photo': 'खाने की फोटो',
  'Water': 'पानी',
  'Weight': 'वज़न',
  'Check in': 'चेक-इन',
  'Search': 'खोजें',
  // home
  'Calories': 'कैलोरी',
  'Steps': 'कदम',
  "Today's plan": 'आज की योजना',
  "Today's workout": 'आज का वर्कआउट',
  'AI coach': 'AI कोच',
  'Explore your fitness': 'अपनी फिटनेस देखें',
  'Customize': 'बदलें',
  'View all': 'सब देखें',
  'Nutrition': 'पोषण',
  'Health': 'सेहत',
  'Library': 'लाइब्रेरी',
  'Community': 'समुदाय',
  'Daily plan': 'रोज़ की योजना',
  'Challenges': 'चैलेंज',
  'Meals and macros': 'खाना और मैक्रो',
  'Reports and conditions': 'रिपोर्ट और स्थितियाँ',
  'Exercises and training': 'एक्सरसाइज़ और ट्रेनिंग',
  'Friends and privacy': 'दोस्त और प्राइवेसी',
  'Today and the week': 'आज और पूरा हफ़्ता',
  'Missions and streaks': 'मिशन और स्ट्रीक',
  // profile
  'Profile': 'प्रोफ़ाइल',
  'Daily targets': 'रोज़ के लक्ष्य',
  'Protein': 'प्रोटीन',
  'Carbs': 'कार्ब्स',
  'Fat': 'फैट',
  'Edit': 'बदलें',
  'Done': 'हो गया',
  'Recalculate': 'दोबारा निकालें',
  'Current weight': 'अभी का वज़न',
  // settings
  'Settings': 'सेटिंग्स',
  'Preferences': 'पसंद',
  'Appearance': 'रूप-रंग',
  'Theme, colours, text size, sounds': 'थीम, रंग, अक्षर का आकार, आवाज़ें',
  'Notifications': 'सूचनाएँ',
  'Reminders, friends, quiet hours': 'रिमाइंडर, दोस्त, शांत समय',
  'Units': 'इकाइयाँ',
  'Language': 'भाषा',
  'Privacy and security': 'प्राइवेसी और सुरक्षा',
  'Privacy and data': 'प्राइवेसी और डेटा',
  'What is stored, who sees it, export': 'क्या सेव है, कौन देखता है, एक्सपोर्ट',
  'Privacy policy': 'प्राइवेसी पॉलिसी',
  'In plain language': 'आसान भाषा में',
  'Change password': 'पासवर्ड बदलें',
  'Connected apps': 'जुड़े हुए ऐप',
  'Health Connect': 'हेल्थ कनेक्ट',
  'Steps, heart rate, sleep': 'कदम, दिल की धड़कन, नींद',
  'Support': 'सहायता',
  'Help and feedback': 'मदद और फीडबैक',
  'App tour': 'ऐप टूर',
  'See the quick intro again': 'छोटा परिचय फिर से देखें',
  'About and licences': 'ऐप के बारे में',
  'Danger zone': 'ख़तरे वाला हिस्सा',
  'Delete data or account': 'डेटा या अकाउंट हटाएँ',
  'Cannot be undone': 'वापस नहीं हो सकता',
  'Sign out': 'साइन आउट',
  'Sign in': 'साइन इन',
  'Account': 'अकाउंट',
  'Light': 'हल्का',
  'Dark': 'गहरा',
  'Auto': 'ऑटो',
  'Theme colour': 'थीम का रंग',
  'Text size': 'अक्षर का आकार',
  'Sounds': 'आवाज़ें',
  'High contrast': 'ज़्यादा कंट्रास्ट',
  'Reduce motion': 'कम एनिमेशन',
  'Friend requests and nudges': 'दोस्ती के अनुरोध और नज',
  'Cheers on your posts': 'आपकी पोस्ट पर चीयर',
  'Quiet hours': 'शांत समय',
  'From': 'से',
  'To': 'तक',
  'Cancel': 'रद्द करें',
  'Save': 'सेव करें',
  'Send': 'भेजें',
  'Back': 'पीछे',
  'Next': 'आगे',
  'Skip': 'छोड़ें',
  'Get started': 'शुरू करें',
  // tour
  'Welcome to Healthy': 'Healthy में आपका स्वागत है',
  'Log food with a photo': 'फोटो से खाना जोड़ें',
  'Add your health report': 'अपनी हेल्थ रिपोर्ट जोड़ें',
  'Check your workout form': 'अपना वर्कआउट फॉर्म जाँचें',
  'Allergy alerts': 'एलर्जी अलर्ट',
  'Workouts and streaks': 'वर्कआउट और स्ट्रीक',
  'Friends and groups': 'दोस्त और ग्रुप',
};
