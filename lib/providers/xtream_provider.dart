import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/xtream_service.dart';
import '../services/favorites_service.dart';
import '../services/custom_groups_service.dart';
import '../services/epg_service.dart';
import '../models/channel.dart';
import '../services/history_service.dart';
import '../services/hidden_channels_service.dart';
import '../services/category_settings_service.dart';

// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

// Servicio global
final xtreamServiceProvider = Provider<XtreamService>((ref) {
  return XtreamService();
});

// Auth
final authProvider = StateProvider<bool>((ref) => false);

// ── LIVE TV ──────────────────────────────────────────
final categoriesProvider = FutureProvider<List<XtreamCategory>>((ref) async {
  return ref.read(xtreamServiceProvider).getCategories();
});

final channelsProvider = FutureProvider.family<List<XtreamChannel>, String>((
  ref,
  categoryId,
) async {
  return ref.read(xtreamServiceProvider).getChannels(categoryId: categoryId);
});

// ── VOD ──────────────────────────────────────────────
final vodCategoriesProvider = FutureProvider<List<XtreamCategory>>((ref) async {
  return ref.read(xtreamServiceProvider).getVodCategories();
});

final vodStreamsProvider = FutureProvider.family<List<VodStream>, String>((
  ref,
  categoryId,
) async {
  print('📦 PROVIDER: vodStreamsProvider called with categoryId: $categoryId');
  final result = await ref
      .read(xtreamServiceProvider)
      .getVodStreams(categoryId: categoryId);
  print(
    '📦 PROVIDER: vodStreamsProvider returning ${result.length} items for categoryId: $categoryId',
  );
  return result;
});

// ── SERIES ───────────────────────────────────────────
final seriesCategoriesProvider = FutureProvider<List<XtreamCategory>>((
  ref,
) async {
  return ref.read(xtreamServiceProvider).getSeriesCategories();
});

final seriesProvider = FutureProvider.family<List<Series>, String>((
  ref,
  categoryId,
) async {
  return ref.read(xtreamServiceProvider).getSeries(categoryId: categoryId);
});

final seriesEpisodesProvider =
    FutureProvider.family<Map<String, List<SeriesEpisode>>, int>((
      ref,
      seriesId,
    ) async {
      return ref.read(xtreamServiceProvider).getSeriesEpisodes(seriesId);
    });

// ── FAVORITOS ────────────────────────────────────────
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService();
});

final favoritesProvider = FutureProvider<List<XtreamChannel>>((ref) async {
  return ref.read(favoritesServiceProvider).getFavorites();
});

final favoriteIdsProvider = FutureProvider<Set<int>>((ref) async {
  final favs = await ref.read(favoritesServiceProvider).getFavorites();
  return favs.map((c) => c.streamId).toSet();
});

// ── CANALES OCULTOS ──────────────────────────────────
final hiddenChannelsServiceProvider = Provider<HiddenChannelsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HiddenChannelsService(prefs);
});

final hiddenChannelIdsProvider =
    StateNotifierProvider<HiddenChannelsNotifier, Set<int>>((ref) {
      final service = ref.watch(hiddenChannelsServiceProvider);
      return HiddenChannelsNotifier(service);
    });

class HiddenChannelsNotifier extends StateNotifier<Set<int>> {
  final HiddenChannelsService _service;

  HiddenChannelsNotifier(this._service) : super(_service.getHiddenIds());

  Future<void> hide(int streamId) async {
    await _service.hide(streamId);
    state = _service.getHiddenIds();
  }

  Future<void> unhide(int streamId) async {
    await _service.unhide(streamId);
    state = _service.getHiddenIds();
  }

  bool isHidden(int streamId) {
    return _service.isHidden(streamId);
  }
}

// ── CATEGORÍAS (SETTINGS Y OCULTAS) ─────────────────
final categorySettingsServiceProvider = Provider<CategorySettingsService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CategorySettingsService(prefs);
});

final hiddenCategoryIdsProvider =
    StateNotifierProvider<HiddenCategoriesNotifier, Set<String>>((ref) {
      final service = ref.watch(categorySettingsServiceProvider);
      return HiddenCategoriesNotifier(service);
    });

class HiddenCategoriesNotifier extends StateNotifier<Set<String>> {
  final CategorySettingsService _service;

  HiddenCategoriesNotifier(this._service)
    : super(_service.getHiddenCategoryIds());

  Future<void> hide(String categoryId) async {
    await _service.hideCategory(categoryId);
    state = _service.getHiddenCategoryIds();
  }

  Future<void> unhide(String categoryId) async {
    await _service.unhideCategory(categoryId);
    state = _service.getHiddenCategoryIds();
  }

  bool isHidden(String categoryId) {
    return _service.isHidden(categoryId);
  }
}

final categorySettingsProvider =
    StateNotifierProvider<
      CategorySettingsNotifier,
      Map<String, CategorySettings>
    >((ref) {
      final service = ref.watch(categorySettingsServiceProvider);
      return CategorySettingsNotifier(service);
    });

class CategorySettingsNotifier
    extends StateNotifier<Map<String, CategorySettings>> {
  final CategorySettingsService _service;

  CategorySettingsNotifier(this._service) : super(_service.getAllSettings());

  CategorySettings getSettings(String categoryId) {
    return state[categoryId] ?? const CategorySettings();
  }

  Future<void> setCustomName(String categoryId, String? name) async {
    await _service.setCustomName(categoryId, name);
    state = _service.getAllSettings();
  }

  Future<void> setSortOrder(String categoryId, ChannelSortOrder order) async {
    await _service.setSortOrder(categoryId, order);
    state = _service.getAllSettings();
  }

  Future<void> setShowFavoritesOnly(String categoryId, bool value) async {
    await _service.setShowFavoritesOnly(categoryId, value);
    state = _service.getAllSettings();
  }
}

// ── NAVEGACIÓN ───────────────────────────────────────
enum MainSection { live, vod, series, favorites, search, groups }

final mainSectionProvider = StateProvider<MainSection>(
  (ref) => MainSection.live,
);
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ── GRUPOS PERSONALIZADOS ─────────────────────────────
final customGroupsServiceProvider = Provider<CustomGroupsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CustomGroupsService(prefs);
});

final customGroupsProvider =
    StateNotifierProvider<CustomGroupsNotifier, List<CustomGroup>>((ref) {
      final service = ref.watch(customGroupsServiceProvider);
      return CustomGroupsNotifier(service);
    });

class CustomGroupsNotifier extends StateNotifier<List<CustomGroup>> {
  final CustomGroupsService _service;

  CustomGroupsNotifier(this._service) : super(_service.getGroups());

  void refresh() {
    state = _service.getGroups();
  }

  Future<void> addGroup(String name, int colorValue) async {
    final group = CustomGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      colorValue: colorValue,
      channelIds: [],
      createdAt: DateTime.now(),
    );
    await _service.addGroup(group);
    refresh();
  }

  Future<void> updateGroup(CustomGroup group) async {
    await _service.updateGroup(group);
    refresh();
  }

  Future<void> deleteGroup(String groupId) async {
    await _service.deleteGroup(groupId);
    refresh();
  }

  Future<void> addChannelToGroup(String groupId, int channelId) async {
    await _service.addChannelToGroup(groupId, channelId);
    refresh();
  }

  Future<void> removeChannelFromGroup(String groupId, int channelId) async {
    await _service.removeChannelFromGroup(groupId, channelId);
    refresh();
  }
}

// ── EPG (Guía de Programación) ────────────────────────
// ── EPG ──────────────────────────────────────────────
final epgServiceProvider = Provider<EpgService>((ref) {
  return EpgService();
});

// Programa actual para un canal por nombre
final currentProgramProvider = FutureProvider.family<EpgProgram?, String>((
  ref,
  channelName,
) async {
  final service = ref.read(epgServiceProvider);
  final prefs = ref.read(sharedPreferencesProvider);

  final baseUrl = prefs.getString('xtream_url') ?? '';
  final username = prefs.getString('xtream_user') ?? '';
  final password = prefs.getString('xtream_pass') ?? '';

  if (baseUrl.isEmpty) return null;

  return service.getCurrentProgram(
    channelName: channelName,
    baseUrl: baseUrl,
    username: username,
    password: password,
  );
});

// Todos los programas de un canal por nombre
final channelProgramsProvider = FutureProvider.family<List<EpgProgram>, String>(
  (ref, channelName) async {
    final service = ref.read(epgServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    final baseUrl = prefs.getString('xtream_url') ?? '';
    final username = prefs.getString('xtream_user') ?? '';
    final password = prefs.getString('xtream_pass') ?? '';

    if (baseUrl.isEmpty) return [];

    return service.getEpgForChannelName(
      channelName: channelName,
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  },
);

// Mapa de nombre de canal → programa actual (carga EPG una sola vez)
final epgMapProvider = FutureProvider<Map<String, EpgProgram?>>((ref) async {
  final service = ref.read(epgServiceProvider);
  final prefs = ref.read(sharedPreferencesProvider);

  final baseUrl = prefs.getString('xtream_url') ?? '';
  final username = prefs.getString('xtream_user') ?? '';
  final password = prefs.getString('xtream_pass') ?? '';

  if (baseUrl.isEmpty) return {};

  final allPrograms = await service.getEpg(
    baseUrl: baseUrl,
    username: username,
    password: password,
  );

  final channelNames = await service.getChannelNames(
    baseUrl: baseUrl,
    username: username,
    password: password,
  );

  // Construir mapa display-name → programa actual
  final now = DateTime.now().toUtc();
  final Map<String, EpgProgram?> result = {};

  for (final program in allPrograms) {
    if (now.isAfter(program.startTime) && now.isBefore(program.stopTime)) {
      final name = channelNames[program.channelId] ?? '';
      if (name.isNotEmpty) {
        result[name] = program;
      }
    }
  }

  return result;
});
// ── HISTORIAL ─────────────────────────────────────────
final historyServiceProvider = Provider<HistoryService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HistoryService(prefs);
});

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<XtreamChannel>>((ref) {
      final service = ref.watch(historyServiceProvider);
      return HistoryNotifier(service);
    });

class HistoryNotifier extends StateNotifier<List<XtreamChannel>> {
  final HistoryService _service;

  HistoryNotifier(this._service) : super(_service.getHistory());

  Future<void> add(XtreamChannel channel) async {
    await _service.addToHistory(channel);
    state = _service.getHistory();
  }

  Future<void> clear() async {
    await _service.clearHistory();
    state = [];
  }
}
