import 'package:shared_preferences/shared_preferences.dart';

import 'humanities_faculties.dart';

/// يحفظ مسار البوابة الإنسانية المختار للتجربة بين الجلسات.
class HumanitiesPrefs {
  HumanitiesPrefs._();

  static const _keyTrack = 'humanities_hub_track_v1';

  static Future<HumanitiesTrack?> loadTrack() async {
    final prefs = await SharedPreferences.getInstance();
    return HumanitiesTrackX.fromId(prefs.getString(_keyTrack));
  }

  static Future<void> saveTrack(HumanitiesTrack track) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTrack, track.id);
  }
}
