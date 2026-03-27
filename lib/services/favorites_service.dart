import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class FavoritesService {
  static const _key = 'favorite_channels';

  Future<List<XtreamChannel>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    return data.map((e) => XtreamChannel.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addFavorite(XtreamChannel channel) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    final encoded = jsonEncode({
      'stream_id': channel.streamId,
      'name': channel.name,
      'stream_icon': channel.streamIcon,
      'category_id': channel.categoryId,
      'stream_type': channel.streamType,
    });
    if (!data.contains(encoded)) {
      data.add(encoded);
      await prefs.setStringList(_key, data);
    }
  }

  Future<void> removeFavorite(int streamId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    data.removeWhere((e) {
      final map = jsonDecode(e);
      return map['stream_id'] == streamId;
    });
    await prefs.setStringList(_key, data);
  }

  Future<bool> isFavorite(int streamId) async {
    final favorites = await getFavorites();
    return favorites.any((c) => c.streamId == streamId);
  }
}
