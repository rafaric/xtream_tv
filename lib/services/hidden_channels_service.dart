import 'package:shared_preferences/shared_preferences.dart';

class HiddenChannelsService {
  final SharedPreferences _prefs;
  static const _key = 'hidden_channels';

  HiddenChannelsService(this._prefs);

  /// Returns the set of hidden channel IDs
  Set<int> getHiddenIds() {
    try {
      final data = _prefs.getStringList(_key) ?? [];
      return data.map((e) => int.parse(e)).toSet();
    } catch (e) {
      // Handle corrupted data gracefully
      return <int>{};
    }
  }

  /// Hides a channel by its stream ID
  Future<void> hide(int streamId) async {
    final hidden = getHiddenIds();
    hidden.add(streamId);
    await _prefs.setStringList(_key, hidden.map((e) => e.toString()).toList());
  }

  /// Unhides a channel by its stream ID
  Future<void> unhide(int streamId) async {
    final hidden = getHiddenIds();
    hidden.remove(streamId);
    await _prefs.setStringList(_key, hidden.map((e) => e.toString()).toList());
  }

  /// Checks if a channel is hidden
  bool isHidden(int streamId) {
    return getHiddenIds().contains(streamId);
  }
}
