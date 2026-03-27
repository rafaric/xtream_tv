import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum ChannelSortOrder { playlist, nameAsc, nameDesc }

class CategorySettings {
  final String? customName;
  final ChannelSortOrder sortOrder;
  final bool showFavoritesOnly;

  const CategorySettings({
    this.customName,
    this.sortOrder = ChannelSortOrder.playlist,
    this.showFavoritesOnly = false,
  });

  CategorySettings copyWith({
    String? customName,
    bool clearCustomName = false,
    ChannelSortOrder? sortOrder,
    bool? showFavoritesOnly,
  }) {
    return CategorySettings(
      customName: clearCustomName ? null : (customName ?? this.customName),
      sortOrder: sortOrder ?? this.sortOrder,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
    );
  }

  Map<String, dynamic> toJson() => {
    'customName': customName,
    'sortOrder': sortOrder.index,
    'showFavoritesOnly': showFavoritesOnly,
  };

  factory CategorySettings.fromJson(Map<String, dynamic> json) {
    return CategorySettings(
      customName: json['customName'] as String?,
      sortOrder: ChannelSortOrder.values[json['sortOrder'] as int? ?? 0],
      showFavoritesOnly: json['showFavoritesOnly'] as bool? ?? false,
    );
  }
}

class CategorySettingsService {
  final SharedPreferences _prefs;
  static const _settingsKey = 'category_settings';
  static const _hiddenKey = 'hidden_categories';

  CategorySettingsService(this._prefs);

  // ─── SETTINGS ────────────────────────────────────────────

  Map<String, CategorySettings> getAllSettings() {
    try {
      final data = _prefs.getString(_settingsKey);
      if (data == null) return {};
      final map = jsonDecode(data) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(
          key,
          CategorySettings.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      return {};
    }
  }

  CategorySettings getSettings(String categoryId) {
    return getAllSettings()[categoryId] ?? const CategorySettings();
  }

  Future<void> saveSettings(
    String categoryId,
    CategorySettings settings,
  ) async {
    final all = getAllSettings();
    all[categoryId] = settings;
    await _prefs.setString(
      _settingsKey,
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> setCustomName(String categoryId, String? name) async {
    final settings = getSettings(categoryId);
    await saveSettings(
      categoryId,
      settings.copyWith(customName: name, clearCustomName: name == null),
    );
  }

  Future<void> setSortOrder(String categoryId, ChannelSortOrder order) async {
    final settings = getSettings(categoryId);
    await saveSettings(categoryId, settings.copyWith(sortOrder: order));
  }

  Future<void> setShowFavoritesOnly(String categoryId, bool value) async {
    final settings = getSettings(categoryId);
    await saveSettings(categoryId, settings.copyWith(showFavoritesOnly: value));
  }

  // ─── HIDDEN CATEGORIES ───────────────────────────────────

  Set<String> getHiddenCategoryIds() {
    try {
      final data = _prefs.getStringList(_hiddenKey) ?? [];
      return data.toSet();
    } catch (e) {
      return <String>{};
    }
  }

  Future<void> hideCategory(String categoryId) async {
    final hidden = getHiddenCategoryIds();
    hidden.add(categoryId);
    await _prefs.setStringList(_hiddenKey, hidden.toList());
  }

  Future<void> unhideCategory(String categoryId) async {
    final hidden = getHiddenCategoryIds();
    hidden.remove(categoryId);
    await _prefs.setStringList(_hiddenKey, hidden.toList());
  }

  bool isHidden(String categoryId) {
    return getHiddenCategoryIds().contains(categoryId);
  }
}
