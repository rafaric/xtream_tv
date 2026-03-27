import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class HistoryService {
  static const _key = 'channel_history';
  static const _maxItems = 20;

  final SharedPreferences _prefs;

  HistoryService(this._prefs);

  List<XtreamChannel> getHistory() {
    final data = _prefs.getStringList(_key) ?? [];
    return data.map((e) => XtreamChannel.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addToHistory(XtreamChannel channel) async {
    final history = getHistory();
    // Eliminar si ya existe
    history.removeWhere((c) => c.streamId == channel.streamId);
    // Agregar al inicio
    history.insert(0, channel);
    // Limitar a _maxItems
    final limited = history.take(_maxItems).toList();
    final encoded = limited
        .map(
          (c) => jsonEncode({
            'stream_id': c.streamId,
            'name': c.name,
            'stream_icon': c.streamIcon,
            'category_id': c.categoryId,
            'stream_type': c.streamType,
          }),
        )
        .toList();
    await _prefs.setStringList(_key, encoded);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_key);
  }
}
