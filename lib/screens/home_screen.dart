import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/xtream_provider.dart';
import '../models/channel.dart';
import '../services/category_settings_service.dart';
import '../services/navigation/grid_navigation_controller.dart';
import '../services/navigation/list_navigation_controller.dart';
import '../services/navigation/navigation_models.dart';
import '../services/navigation/navigation_constants.dart';
import 'login_screen.dart';
import 'player_screen.dart';
import 'vod_detail_screen.dart';
import 'series_detail_screen.dart';
import 'groups_screen.dart';
// Preview temporalmente deshabilitado durante migración
// import '../widgets/channel_preview.dart';
import 'dart:async';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedNavIndex =
      1; // Índice en barra de navegación (0=nav), default Live TV
  int _selectedCategoryIndex = 0; // Índice en lista de categorías
  int _selectedContentIndex = 0;
  int _focusColumn = 1; // 0=nav, 1=categorías, 2=contenido
  XtreamChannel? _previewChannel;
  Timer? _previewTimer;
  // Preview temporalmente deshabilitado
  // VlcPlayerController? _previewController;
  bool _playerScreenOpen = false;
  bool _detailScreenOpen = false;

  // Long press detection para context menu
  Timer? _longPressTimer;
  bool _isLongPress = false;

  // Flag para bloquear teclas cuando hay diálogo abierto
  bool _isDialogOpen = false;

  final _categoryScrollController = ScrollController();
  final _contentScrollController = ScrollController();

  // Íconos y labels de la barra lateral
  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.search, 'label': 'Buscar', 'section': MainSection.search},
    {'icon': Icons.tv, 'label': 'En Vivo', 'section': MainSection.live},
    {'icon': Icons.movie, 'label': 'Películas', 'section': MainSection.vod},
    {
      'icon': Icons.video_library,
      'label': 'Series',
      'section': MainSection.series,
    },
    {
      'icon': Icons.star,
      'label': 'Favoritos',
      'section': MainSection.favorites,
    },
    {
      'icon': Icons.folder_outlined,
      'label': 'Grupos',
      'section': MainSection.groups,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currentSection = ref.watch(mainSectionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: _handleGlobalKey,
        child: Row(
          children: [
            // Columna 1: Barra de navegación
            _buildNavBar(currentSection),

            // Columna 2: Categorías
            _buildCategoriesColumn(currentSection),

            // Divisor
            Container(
              width: 1,
              color: Colors.deepPurple.withValues(alpha: 0.3),
            ),

            // Columna 3: Contenido
            Expanded(child: _buildContentColumn(currentSection)),
          ],
        ),
      ),
    );
  }

  // ── COLUMNA 1: Barra de navegación ──────────────────

  Widget _buildNavBar(MainSection currentSection) {
    return Container(
      width: 64,
      color: const Color(0xFF0A0A15),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Logo
          const Icon(Icons.live_tv, color: Colors.deepPurple, size: 32),
          const SizedBox(height: 24),
          const Divider(color: Colors.deepPurple, height: 1),
          const SizedBox(height: 16),
          // Items de navegación
          Expanded(
            child: Column(
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = currentSection == item['section'];
                final isFocused =
                    _focusColumn == 0 && index == _selectedNavIndex;
                return _buildNavItem(
                  icon: item['icon'] as IconData,
                  label: item['label'] as String,
                  isSelected: isSelected,
                  isFocused: isFocused,
                  onTap: () {
                    ref.read(mainSectionProvider.notifier).state =
                        item['section'] as MainSection;
                    setState(() {
                      _selectedNavIndex = index;
                      _selectedCategoryIndex = 0;
                      _selectedContentIndex = 0;
                      _focusColumn = 1;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          // Botón logout
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: IconButton(
              onPressed: _goToLogin,
              icon: const Icon(Icons.logout, color: Colors.white38, size: 22),
              tooltip: 'Cerrar sesión',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isFocused,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.deepPurple
                : isFocused
                ? Colors.deepPurple.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white54,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ── COLUMNA 2: Categorías ────────────────────────────

  Widget _buildCategoriesColumn(MainSection section) {
    if (section == MainSection.search) {
      return _buildSearchColumn();
    }

    if (section == MainSection.favorites) {
      return _buildFavoritesLabel();
    }

    if (section == MainSection.groups) {
      return _buildGroupsListColumn();
    }

    AsyncValue<List<XtreamCategory>> categoriesAsync;
    switch (section) {
      case MainSection.live:
        categoriesAsync = ref.watch(categoriesProvider);
        break;
      case MainSection.vod:
        categoriesAsync = ref.watch(vodCategoriesProvider);
        break;
      case MainSection.series:
        categoriesAsync = ref.watch(seriesCategoriesProvider);
        break;
      default:
        categoriesAsync = ref.watch(categoriesProvider);
    }

    return Container(
      width: 240,
      color: const Color(0xFF0D0D1A),
      child: categoriesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
        error: (e, _) => _buildErrorWidget(e.toString()),
        data: (categories) => _buildCategoriesList(categories),
      ),
    );
  }

  Widget _buildCategoriesList(List<XtreamCategory> categories) {
    final hiddenIds = ref.watch(hiddenCategoryIdsProvider);
    final settings = ref.watch(categorySettingsProvider);
    final section = ref.watch(mainSectionProvider);

    // Verificar si "Todos" tiene contenido
    bool showTodos = true;
    if (section == MainSection.vod) {
      final vodAsync = ref.watch(vodStreamsProvider('__all__'));
      showTodos = vodAsync.maybeWhen(
        data: (v) => v.isNotEmpty,
        orElse: () => false,
      );
    } else if (section == MainSection.series) {
      final seriesAsync = ref.watch(seriesProvider('__all__'));
      showTodos = seriesAsync.maybeWhen(
        data: (s) => s.isNotEmpty,
        orElse: () => false,
      );
    }

    final allCategories = [
      if (showTodos)
        XtreamCategory(categoryId: '__all__', categoryName: 'Todos'),
      ...categories.where((c) => !hiddenIds.contains(c.categoryId)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'CATEGORÍAS',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _categoryScrollController,
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final category = allCategories[index];
              final isSelected = index == _selectedCategoryIndex;
              final isFocused = _focusColumn == 1 && isSelected;
              final catSettings = settings[category.categoryId];
              final displayName =
                  catSettings?.customName ?? category.categoryName;
              return _buildCategoryItem(
                category,
                displayName,
                isSelected,
                isFocused,
                index,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(
    XtreamCategory category,
    String displayName,
    bool isSelected,
    bool isFocused,
    int index,
  ) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategoryIndex = index;
        _selectedContentIndex = 0;
        _focusColumn = 2;
      }),
      onLongPress: category.categoryId != '__all__'
          ? () => _showCategoryContextMenu(category, displayName)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isFocused
              ? Colors.deepPurple
              : isSelected
              ? Colors.deepPurple.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFocused ? Colors.deepPurpleAccent : Colors.transparent,
          ),
        ),
        child: Text(
          displayName,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFavoritesLabel() {
    return Container(
      width: 240,
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: const Text(
        'FAVORITOS',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSearchColumn() {
    return Container(
      width: 240,
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Text(
            'BÚSQUEDA',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 16),
          Text('Próximamente', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  // ── COLUMNA 3: Contenido ─────────────────────────────

  Widget _buildContentColumn(MainSection section) {
    if (section == MainSection.search) {
      return const Center(
        child: Text(
          'Búsqueda próximamente',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    if (section == MainSection.favorites) {
      final favAsync = ref.watch(favoritesProvider);
      return favAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
        error: (e, _) => _buildErrorWidget(e.toString()),
        data: (channels) => channels.isEmpty
            ? _buildEmptyWidget(
                'No tenés favoritos todavía.\nLong press en un canal para agregar.',
              )
            : _buildLiveGrid(channels),
      );
    }

    if (section == MainSection.groups) {
      return _buildGroupChannelsSection();
    }

    // Obtener categoría seleccionada
    AsyncValue<List<XtreamCategory>> categoriesAsync;
    switch (section) {
      case MainSection.live:
        categoriesAsync = ref.watch(categoriesProvider);
        break;
      case MainSection.vod:
        categoriesAsync = ref.watch(vodCategoriesProvider);
        break;
      case MainSection.series:
        categoriesAsync = ref.watch(seriesCategoriesProvider);
        break;
      default:
        categoriesAsync = ref.watch(categoriesProvider);
    }

    return categoriesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
      error: (e, _) => _buildErrorWidget(e.toString()),
      data: (categories) {
        final hiddenIds = ref.watch(hiddenCategoryIdsProvider);
        final allCategories = [
          XtreamCategory(categoryId: '__all__', categoryName: 'Todos'),
          ...categories.where((c) => !hiddenIds.contains(c.categoryId)),
        ];
        if (_selectedCategoryIndex >= allCategories.length) {
          // Ajustar índice si quedó fuera de rango
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedCategoryIndex = allCategories.length - 1;
              });
            }
          });
          return const SizedBox();
        }
        final selected = allCategories[_selectedCategoryIndex];
        final categoryId = selected.categoryId == '__all__'
            ? null
            : selected.categoryId;

        switch (section) {
          case MainSection.live:
            final channelsAsync = ref.watch(
              channelsProvider(categoryId ?? '__all__'),
            );
            return channelsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
              error: (e, _) => _buildErrorWidget(e.toString()),
              data: (channels) => _buildLiveGrid(channels),
            );
          case MainSection.vod:
            final vodAsync = ref.watch(
              vodStreamsProvider(categoryId ?? '__all__'),
            );
            return vodAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
              error: (e, _) => _buildErrorWidget(e.toString()),
              data: (vods) => _buildVodGrid(vods),
            );
          case MainSection.series:
            final seriesAsync = ref.watch(
              seriesProvider(categoryId ?? '__all__'),
            );
            return seriesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
              error: (e, _) => _buildErrorWidget(e.toString()),
              data: (series) => _buildSeriesGrid(series),
            );
          default:
            return const SizedBox();
        }
      },
    );
  }

  // ── GRILLAS DE CONTENIDO ─────────────────────────────

  Widget _buildLiveGrid(List<XtreamChannel> channels) {
    final hiddenIds = ref.watch(hiddenChannelIdsProvider);
    final categoryId = _getSelectedCategoryId() ?? '__all__';
    final settings = ref.watch(categorySettingsProvider);
    final catSettings = settings[categoryId] ?? const CategorySettings();
    final favoriteIds = ref.watch(favoriteIdsProvider);

    // Filtrar canales ocultos
    var filteredChannels = channels
        .where((c) => !hiddenIds.contains(c.streamId))
        .toList();

    // Filtrar solo favoritos si está activo
    if (catSettings.showFavoritesOnly) {
      final favIds = favoriteIds.maybeWhen(
        data: (ids) => ids,
        orElse: () => <int>{},
      );
      filteredChannels = filteredChannels
          .where((c) => favIds.contains(c.streamId))
          .toList();
    }

    // Aplicar ordenamiento
    switch (catSettings.sortOrder) {
      case ChannelSortOrder.nameAsc:
        filteredChannels.sort((a, b) => a.name.compareTo(b.name));
        break;
      case ChannelSortOrder.nameDesc:
        filteredChannels.sort((a, b) => b.name.compareTo(a.name));
        break;
      case ChannelSortOrder.playlist:
        // Mantener orden original
        break;
    }

    if (filteredChannels.isEmpty) {
      return _buildEmptyWidget(
        catSettings.showFavoritesOnly
            ? 'No hay favoritos en esta categoría'
            : 'No hay canales en esta categoría',
      );
    }
    final epgMapAsync = ref.watch(epgMapProvider);

    return epgMapAsync.when(
      loading: () => _buildChannelList(filteredChannels, {}, favoriteIds),
      error: (e, _) => _buildChannelList(filteredChannels, {}, favoriteIds),
      data: (epgMap) =>
          _buildChannelList(filteredChannels, epgMap, favoriteIds),
    );
  }

  Widget _buildChannelList(
    List<XtreamChannel> channels,
    Map<String, EpgProgram?> epgMap,
    AsyncValue<Set<int>> favoriteIds,
  ) {
    return Column(
      children: [
        // Preview temporalmente deshabilitado durante migración a BetterPlayer
        // TODO: Reimplementar preview con BetterPlayer

        // Lista de canales
        Expanded(
          child: ListView.builder(
            controller: _contentScrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              final isSelected =
                  _focusColumn == 2 && index == _selectedContentIndex;
              final isFav = favoriteIds.maybeWhen(
                data: (ids) => ids.contains(channel.streamId),
                orElse: () => false,
              );
              final program = _findEpgForChannel(channel.name, epgMap);

              // Disparar preview al seleccionar
              if (isSelected && !_playerScreenOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_playerScreenOpen &&
                      _previewChannel?.streamId != channel.streamId) {
                    _schedulePreview(channel, epgMap);
                  }
                });
              }

              return _buildChannelRow(
                channel,
                isSelected,
                isFav,
                program,
                index,
              );
            },
          ),
        ),
      ],
    );
  }

  EpgProgram? _findEpgForChannel(
    String channelName,
    Map<String, EpgProgram?> epgMap,
  ) {
    if (epgMap.isEmpty) return null;

    final normalized = channelName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );

    // Búsqueda exacta primero
    for (final entry in epgMap.entries) {
      final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key == normalized) return entry.value;
    }

    // Búsqueda parcial
    for (final entry in epgMap.entries) {
      final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key.contains(normalized) || normalized.contains(key)) {
        return entry.value;
      }
    }

    return null;
  }

  Widget _buildChannelRow(
    XtreamChannel channel,
    bool isSelected,
    bool isFav,
    EpgProgram? program,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _openLivePlayer(channel),
      onLongPress: () => _showChannelContextMenu(channel, isFav),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withValues(alpha: 0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.deepPurpleAccent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Número de canal
            SizedBox(
              width: 36,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Logo
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: channel.streamIcon.isNotEmpty
                    ? Image.network(
                        channel.streamIcon,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.tv,
                          color: Colors.deepPurple,
                          size: 24,
                        ),
                      )
                    : const Icon(Icons.tv, color: Colors.deepPurple, size: 24),
              ),
            ),

            // Info canal + EPG
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre del canal
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          channel.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFav) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 12,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Programa actual
                  if (program != null) ...[
                    Text(
                      program.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Barra de progreso
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: program.progress,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.deepPurple,
                              ),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          program.timeRange,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      'Sin información de programación',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // Indicador de reproducción
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.deepPurpleAccent,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVodGrid(List<VodStream> vods) {
    if (vods.isEmpty) {
      return _buildEmptyWidget('No hay películas en esta categoría');
    }
    return GridView.builder(
      controller: _contentScrollController,
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: vods.length,
      itemBuilder: (context, index) {
        final isSelected = _focusColumn == 2 && index == _selectedContentIndex;
        return _buildVodCard(vods[index], isSelected);
      },
    );
  }

  Widget _buildSeriesGrid(List<Series> series) {
    if (series.isEmpty) {
      return _buildEmptyWidget('No hay series en esta categoría');
    }
    return GridView.builder(
      controller: _contentScrollController,
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final isSelected = _focusColumn == 2 && index == _selectedContentIndex;
        return _buildSeriesCard(series[index], isSelected);
      },
    );
  }

  // ── CARDS ────────────────────────────────────────────

  Widget _buildChannelCard(XtreamChannel channel, bool isSelected, bool isFav) {
    return GestureDetector(
      onTap: () => _openLivePlayer(channel),
      onLongPress: () => _showChannelContextMenu(channel, isFav),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent
                : Colors.deepPurple.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (channel.streamIcon.isNotEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          channel.streamIcon,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => const Icon(
                            Icons.tv,
                            color: Colors.deepPurple,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.tv, color: Colors.deepPurple, size: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Text(
                    channel.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (isFav)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.star, color: Colors.amber, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVodCard(VodStream vod, bool isSelected) {
    return GestureDetector(
      onTap: () => _openVodDetail(vod),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent
                : Colors.deepPurple.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
                child: vod.streamIcon.isNotEmpty
                    ? Image.network(
                        vod.streamIcon,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.movie,
                          color: Colors.deepPurple,
                          size: 40,
                        ),
                      )
                    : const Icon(
                        Icons.movie,
                        color: Colors.deepPurple,
                        size: 40,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vod.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (vod.rating > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          vod.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeriesCard(Series series, bool isSelected) {
    return GestureDetector(
      onTap: () => _openSeriesDetail(series),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent
                : Colors.deepPurple.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
                child: series.cover.isNotEmpty
                    ? Image.network(
                        series.cover,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.video_library,
                          color: Colors.deepPurple,
                          size: 40,
                        ),
                      )
                    : const Icon(
                        Icons.video_library,
                        color: Colors.deepPurple,
                        size: 40,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (series.rating > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          series.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── NAVEGACIÓN POR TECLADO ───────────────────────────

  // Helper: obtener itemCount actual de los providers
  int _getCurrentItemCount() {
    final section = ref.read(mainSectionProvider);

    if (section == MainSection.vod) {
      final categoryId = _getSelectedCategoryId() ?? '__all__';
      final vodAsync = ref.read(vodStreamsProvider(categoryId));
      return vodAsync.maybeWhen(data: (v) => v.length, orElse: () => 0);
    } else if (section == MainSection.series) {
      final categoryId = _getSelectedCategoryId() ?? '__all__';
      final seriesAsync = ref.read(seriesProvider(categoryId));
      return seriesAsync.maybeWhen(data: (s) => s.length, orElse: () => 0);
    } else if (section == MainSection.live) {
      final categoryId = _getSelectedCategoryId() ?? '__all__';
      final channelsAsync = ref.read(channelsProvider(categoryId));
      return channelsAsync.maybeWhen(
        data: (ch) {
          final hiddenIds = ref.read(hiddenChannelIdsProvider);
          return ch.where((c) => !hiddenIds.contains(c.streamId)).length;
        },
        orElse: () => 0,
      );
    } else if (section == MainSection.favorites) {
      final favsAsync = ref.read(favoritesProvider);
      return favsAsync.maybeWhen(data: (ch) => ch.length, orElse: () => 0);
    }

    return 0;
  }

  // Helper: navegar con controller on-demand
  NavigationResult? _navigateWithController(Function(dynamic) navigate) {
    final section = ref.read(mainSectionProvider);
    final isGrid = section == MainSection.vod || section == MainSection.series;
    final itemCount = _getCurrentItemCount();

    if (itemCount == 0) return null;

    if (isGrid) {
      final controller = GridNavigationController(
        itemCount: itemCount,
        columnsPerRow: NavigationConstants.gridColumnsPerRow,
        initialIndex: _selectedContentIndex,
      );
      return navigate(controller);
    } else {
      final controller = ListNavigationController(
        itemCount: itemCount,
        initialIndex: _selectedContentIndex,
      );
      return navigate(controller);
    }
  }

  void _handleGlobalKey(KeyEvent event) {
    // Si el player está abierto, ignorar todas las teclas
    if (_playerScreenOpen) return;
    // Si hay un detail screen abierto, ignorar todas las teclas
    if (_detailScreenOpen) return;
    // Si hay un diálogo abierto, no interceptar teclas
    if (_isDialogOpen) return;

    final isSelectKey =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter;

    // ─────────────────────────────────────────────────────────────
    // LONG PRESS DETECTION para context menu (columnas 1 y 2)
    // ─────────────────────────────────────────────────────────────
    if (isSelectKey && (_focusColumn == 1 || _focusColumn == 2)) {
      if (event is KeyDownEvent) {
        _isLongPress = false;
        _longPressTimer?.cancel();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _isLongPress = true;
            if (_focusColumn == 1) {
              _handleCategoryLongPress();
            } else {
              _handleLongPress();
            }
          }
        });
        return;
      } else if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (!_isLongPress) {
          // Short press: abrir contenido
          _handleSelect();
        }
        _isLongPress = false;
        return;
      }
    }

    // Solo procesar KeyDownEvent para el resto de teclas
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_focusColumn == 2) {
        // Contenido
        final section = ref.read(mainSectionProvider);
        final isGrid =
            section == MainSection.vod || section == MainSection.series;

        if (isGrid) {
          // Grids: navegar dentro de la grilla primero
          final result = _navigateWithController((controller) {
            if (controller is GridNavigationController) {
              return controller.navigateLeft();
            }
            return null;
          });

          if (result != null && result.success) {
            setState(() {
              _selectedContentIndex = result.newIndex;
            });
            _scrollContentToSelected();
          } else if (result != null && result.edge == NavigationEdge.left) {
            // En el borde izquierdo: cambiar a categorías
            setState(() => _focusColumn = 1);
          } else if (result == null) {
            // Grid vacío o sin controller: volver a categorías
            setState(() => _focusColumn = 1);
          }
        } else {
          // Listas: LEFT siempre vuelve a categorías
          setState(() => _focusColumn = 1);
        }
      } else if (_focusColumn > 0) {
        setState(() => _focusColumn--);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_focusColumn == 2) {
        // Contenido: solo grids tienen navegación horizontal
        final section = ref.read(mainSectionProvider);
        final isGrid =
            section == MainSection.vod || section == MainSection.series;

        if (isGrid) {
          final result = _navigateWithController((controller) {
            if (controller is GridNavigationController) {
              return controller.navigateRight();
            }
            return null;
          });

          if (result != null && result.success) {
            setState(() {
              _selectedContentIndex = result.newIndex;
            });
            _scrollContentToSelected();
          }
        }
      } else if (_focusColumn < 2) {
        setState(() => _focusColumn++);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusColumn == 2) {
        // Contenido: navegar con controller on-demand
        final result = _navigateWithController((controller) {
          if (controller is GridNavigationController) {
            return controller.navigateUp();
          } else if (controller is ListNavigationController) {
            return controller.navigateUp();
          }
          return null;
        });

        if (result != null && result.success) {
          setState(() {
            _selectedContentIndex = result.newIndex;
          });
          _scrollContentToSelected();
        }
      } else if (_focusColumn == 1) {
        // Categorías
        setState(() {
          if (_selectedCategoryIndex > 0) _selectedCategoryIndex--;
          _scrollCategoryToSelected();
        });
      } else if (_focusColumn == 0) {
        // Navegación principal
        setState(() {
          if (_selectedNavIndex > 0) _selectedNavIndex--;
        });
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_focusColumn == 2) {
        // Contenido: crear controller on-demand con datos actuales
        final section = ref.read(mainSectionProvider);
        final isGrid =
            section == MainSection.vod || section == MainSection.series;

        NavigationResult? result;

        if (isGrid) {
          // Crear grid controller on-demand
          int itemCount = 0;
          if (section == MainSection.vod) {
            final categoryId = _getSelectedCategoryId() ?? '__all__';
            final vodAsync = ref.read(vodStreamsProvider(categoryId));
            itemCount = vodAsync.maybeWhen(
              data: (v) => v.length,
              orElse: () => 0,
            );
          } else if (section == MainSection.series) {
            final categoryId = _getSelectedCategoryId() ?? '__all__';
            final seriesAsync = ref.read(seriesProvider(categoryId));
            itemCount = seriesAsync.maybeWhen(
              data: (s) => s.length,
              orElse: () => 0,
            );
          }

          if (itemCount > 0) {
            final controller = GridNavigationController(
              itemCount: itemCount,
              columnsPerRow: NavigationConstants.gridColumnsPerRow,
              initialIndex: _selectedContentIndex,
            );
            result = controller.navigateDown();
          }
        } else {
          // Crear list controller on-demand
          int itemCount = 0;
          if (section == MainSection.live) {
            final categoryId = _getSelectedCategoryId() ?? '__all__';
            final channelsAsync = ref.read(channelsProvider(categoryId));
            itemCount = channelsAsync.maybeWhen(
              data: (ch) {
                final hiddenIds = ref.read(hiddenChannelIdsProvider);
                return ch.where((c) => !hiddenIds.contains(c.streamId)).length;
              },
              orElse: () => 0,
            );
          } else if (section == MainSection.favorites) {
            final favsAsync = ref.read(favoritesProvider);
            itemCount = favsAsync.maybeWhen(
              data: (ch) => ch.length,
              orElse: () => 0,
            );
          }

          if (itemCount > 0) {
            final controller = ListNavigationController(
              itemCount: itemCount,
              initialIndex: _selectedContentIndex,
            );
            result = controller.navigateDown();
          }
        }

        if (result != null && result.success) {
          setState(() {
            _selectedContentIndex = result!.newIndex;
          });
          _scrollContentToSelected();
        }
      } else if (_focusColumn == 1) {
        // Categorías
        setState(() {
          _selectedCategoryIndex++;
          _scrollCategoryToSelected();
        });
      } else if (_focusColumn == 0) {
        // Navegación principal
        setState(() {
          if (_selectedNavIndex < _navItems.length - 1) _selectedNavIndex++;
        });
      }
    } else if (isSelectKey) {
      // Select en columnas 0 o 1 (no contenido)
      _handleSelect();
    }
  }

  void _handleLongPress() {
    final section = ref.read(mainSectionProvider);

    // Solo mostrar context menu para Live TV y Favoritos
    if (section == MainSection.live || section == MainSection.favorites) {
      final channelsAsync = section == MainSection.favorites
          ? ref.read(favoritesProvider)
          : ref.read(channelsProvider(_getSelectedCategoryId() ?? '__all__'));
      final channels = channelsAsync.maybeWhen(
        data: (ch) => ch,
        orElse: () => <XtreamChannel>[],
      );
      final hiddenIds = ref.read(hiddenChannelIdsProvider);
      final filteredChannels = channels
          .where((c) => !hiddenIds.contains(c.streamId))
          .toList();

      if (_selectedContentIndex < filteredChannels.length) {
        final channel = filteredChannels[_selectedContentIndex];
        final favIds = ref
            .read(favoriteIdsProvider)
            .maybeWhen(data: (ids) => ids, orElse: () => <int>{});
        final isFav = favIds.contains(channel.streamId);
        _showChannelContextMenu(channel, isFav);
      }
    }
  }

  void _handleCategoryLongPress() {
    final section = ref.read(mainSectionProvider);

    // Solo para secciones con categorías (Live, VOD, Series)
    if (section != MainSection.live &&
        section != MainSection.vod &&
        section != MainSection.series) {
      return;
    }

    // Obtener la lista de categorías según la sección
    AsyncValue<List<XtreamCategory>> categoriesAsync;
    switch (section) {
      case MainSection.live:
        categoriesAsync = ref.read(categoriesProvider);
        break;
      case MainSection.vod:
        categoriesAsync = ref.read(vodCategoriesProvider);
        break;
      case MainSection.series:
        categoriesAsync = ref.read(seriesCategoriesProvider);
        break;
      default:
        return;
    }

    final categories = categoriesAsync.maybeWhen(
      data: (cats) => cats,
      orElse: () => <XtreamCategory>[],
    );

    final hiddenIds = ref.read(hiddenCategoryIdsProvider);
    final settings = ref.read(categorySettingsProvider);

    final allCategories = [
      XtreamCategory(categoryId: '__all__', categoryName: 'Todos'),
      ...categories.where((c) => !hiddenIds.contains(c.categoryId)),
    ];

    if (_selectedCategoryIndex < allCategories.length) {
      final category = allCategories[_selectedCategoryIndex];

      // No mostrar menu para "Todos"
      if (category.categoryId == '__all__') return;

      final catSettings = settings[category.categoryId];
      final displayName = catSettings?.customName ?? category.categoryName;
      _showCategoryContextMenu(category, displayName);
    }
  }

  void _handleSelect() {
    if (_focusColumn == 0) {
      final section = _navItems[_selectedNavIndex]['section'] as MainSection;
      ref.read(mainSectionProvider.notifier).state = section;
      setState(() {
        _selectedCategoryIndex = 0;
        _selectedContentIndex = 0;
        _focusColumn = 1;
      });
    } else if (_focusColumn == 1) {
      setState(() {
        _focusColumn = 2;
        _selectedContentIndex = 0;
      });
    } else if (_focusColumn == 2) {
      // Abrir el contenido seleccionado
      _openSelectedContent();
    }
  }

  void _openSelectedContent() {
    final section = ref.read(mainSectionProvider);

    if (section == MainSection.live || section == MainSection.favorites) {
      final channelsAsync = section == MainSection.favorites
          ? ref.read(favoritesProvider)
          : ref.read(channelsProvider(_getSelectedCategoryId() ?? '__all__'));
      final channels = channelsAsync.maybeWhen(
        data: (ch) => ch,
        orElse: () => <XtreamChannel>[],
      );
      final hiddenIds = ref.read(hiddenChannelIdsProvider);
      final filteredChannels = channels
          .where((c) => !hiddenIds.contains(c.streamId))
          .toList();
      if (_selectedContentIndex < filteredChannels.length) {
        _openLivePlayer(filteredChannels[_selectedContentIndex]);
      }
    } else if (section == MainSection.vod) {
      final vodAsync = ref.read(
        vodStreamsProvider(_getSelectedCategoryId() ?? '__all__'),
      );
      final vods = vodAsync.maybeWhen(
        data: (v) => v,
        orElse: () => <VodStream>[],
      );
      if (_selectedContentIndex < vods.length) {
        _openVodDetail(vods[_selectedContentIndex]);
      }
    } else if (section == MainSection.series) {
      final seriesAsync = ref.read(
        seriesProvider(_getSelectedCategoryId() ?? '__all__'),
      );
      final series = seriesAsync.maybeWhen(
        data: (s) => s,
        orElse: () => <Series>[],
      );
      if (_selectedContentIndex < series.length) {
        _openSeriesDetail(series[_selectedContentIndex]);
      }
    }
  }

  String? _getSelectedCategoryId() {
    final section = ref.read(mainSectionProvider);
    final hiddenIds = ref.read(hiddenCategoryIdsProvider);
    AsyncValue<List<XtreamCategory>> categoriesAsync;
    switch (section) {
      case MainSection.vod:
        categoriesAsync = ref.read(vodCategoriesProvider);
        break;
      case MainSection.series:
        categoriesAsync = ref.read(seriesCategoriesProvider);
        break;
      default:
        categoriesAsync = ref.read(categoriesProvider);
    }
    final categories = categoriesAsync.maybeWhen(
      data: (cats) => cats,
      orElse: () => <XtreamCategory>[],
    );
    final allCategories = [
      XtreamCategory(categoryId: '__all__', categoryName: 'Todos'),
      ...categories.where((c) => !hiddenIds.contains(c.categoryId)),
    ];
    if (_selectedCategoryIndex >= allCategories.length) return null;
    final selected = allCategories[_selectedCategoryIndex];
    return selected.categoryId == '__all__' ? null : selected.categoryId;
  }

  void _scrollCategoryToSelected() {
    const itemHeight = 44.0;
    final offset = _selectedCategoryIndex * itemHeight;
    if (_categoryScrollController.hasClients) {
      _categoryScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollContentToSelected() {
    if (!_contentScrollController.hasClients) return;

    final section = ref.read(mainSectionProvider);

    // Para grillas (VOD/Series), calcular offset basado en filas
    if (section == MainSection.vod || section == MainSection.series) {
      final currentRow =
          _selectedContentIndex ~/ NavigationConstants.gridColumnsPerRow;
      final offset = currentRow * NavigationConstants.gridItemHeight;

      _contentScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      // Para listas (Live TV, Favoritos)
      const itemHeight = NavigationConstants.listItemHeight;
      final offset = _selectedContentIndex * itemHeight;

      _contentScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }
  // ── HELPERS ──────────────────────────────────────────

  Widget _buildGroupChannelsSection() {
    final groups = ref.watch(customGroupsProvider);
    final channelsAsync = ref.watch(channelsProvider('__all__'));

    if (groups.isEmpty) {
      return Stack(
        children: [
          _buildEmptyWidget(
            'No tenés grupos todavía.\nTocá el botón + para crear uno.',
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'add_group',
              backgroundColor: Colors.deepPurple,
              onPressed: () => _openGroupsScreen(),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      );
    }

    // Obtener el grupo seleccionado en la columna 2
    final selectedIndex = _selectedCategoryIndex.clamp(0, groups.length - 1);
    final selectedGroup = groups[selectedIndex];

    return channelsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
      error: (e, _) => _buildErrorWidget(e.toString()),
      data: (allChannels) {
        final hiddenIds = ref.watch(hiddenChannelIdsProvider);
        final groupChannels = allChannels
            .where(
              (c) =>
                  selectedGroup.channelIds.contains(c.streamId) &&
                  !hiddenIds.contains(c.streamId),
            )
            .toList();

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del grupo
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(selectedGroup.colorValue),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.folder,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        selectedGroup.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${groupChannels.length} canales',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Grilla de canales
                Expanded(
                  child: groupChannels.isEmpty
                      ? _buildEmptyWidget(
                          'No hay canales en este grupo.\nAgregalos desde la pantalla de grupos.',
                        )
                      : GridView.builder(
                          controller: _contentScrollController,
                          padding: const EdgeInsets.all(20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 1.6,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: groupChannels.length,
                          itemBuilder: (context, index) {
                            final channel = groupChannels[index];
                            return _buildChannelCard(
                              channel,
                              _focusColumn == 2 &&
                                  index == _selectedContentIndex,
                              false,
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'manage_groups',
                backgroundColor: Colors.deepPurple,
                onPressed: () => _openGroupsScreen(),
                child: const Icon(Icons.edit),
              ),
            ),
          ],
        );
      },
    );
  }

  //ignore: unused_element
  Widget _buildGroupCard(
    CustomGroup group,
    List<XtreamChannel> channels,
    int index,
  ) {
    final isSelected = _focusColumn == 2 && index == _selectedContentIndex;
    final hasChannels = channels.isNotEmpty;

    return GestureDetector(
      onTap: () => _openGroupsScreen(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent
                : Colors.deepPurple.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(group.colorValue).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.folder,
                    color: Color(group.colorValue),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Text(
                    group.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${channels.length} canales',
                  style: TextStyle(
                    color: isSelected ? Colors.white60 : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                hasChannels ? Icons.check_circle : Icons.circle_outlined,
                color: hasChannels ? Colors.green : Colors.white24,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGroupsScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GroupsScreen()));
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _goToLogin,
            icon: const Icon(Icons.settings),
            label: const Text('Cambiar credenciales'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsListColumn() {
    final groups = ref.watch(customGroupsProvider);

    return Container(
      width: 240,
      color: const Color(0xFF0D0D1A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'GRUPOS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? const Center(
                    child: Text(
                      'No hay grupos',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isSelected = index == _selectedCategoryIndex;
                      final isFocused = _focusColumn == 1 && isSelected;

                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategoryIndex = index;
                          _focusColumn = 2;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? Colors.deepPurple
                                : isSelected
                                ? Colors.deepPurple.withValues(alpha: 0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFocused
                                  ? Colors.deepPurpleAccent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Color(group.colorValue),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  group.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white60,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${group.channelIds.length}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.white38, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _schedulePreview(
    XtreamChannel channel,
    Map<String, EpgProgram?> epgMap,
  ) {
    // Preview temporalmente deshabilitado durante migración
    // TODO: Reimplementar con BetterPlayer
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      setState(() {
        _previewChannel = channel;
      });
    });
  }

  // ignore: unused_element
  void _clearPreview() {
    _previewTimer?.cancel();
    setState(() {
      _previewChannel = null;
    });
  }

  void _openLivePlayer(XtreamChannel channel) async {
    setState(() => _playerScreenOpen = true);
    final service = ref.read(xtreamServiceProvider);
    final url = service.getStreamUrl(channel.streamId);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(channel: channel, streamUrl: url),
      ),
    );

    // Cuando vuelve del player
    if (mounted) {
      setState(() {
        _playerScreenOpen = false;
        _focusColumn = 1; // Devolver foco a las categorías
      });
    }
  }

  void _openVodDetail(VodStream vod) async {
    setState(() => _detailScreenOpen = true);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => VodDetailScreen(vod: vod)));
    if (mounted) {
      setState(() {
        _detailScreenOpen = false;
        _focusColumn = 1; // Devolver foco a las categorías
      });
    }
  }

  void _openSeriesDetail(Series series) async {
    setState(() => _detailScreenOpen = true);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)),
    );
    if (mounted) {
      setState(() {
        _detailScreenOpen = false;
        _focusColumn = 1; // Devolver foco a las categorías
      });
    }
  }

  Future<void> _toggleFavorite(XtreamChannel channel, bool isFav) async {
    final service = ref.read(favoritesServiceProvider);
    if (isFav) {
      await service.removeFavorite(channel.streamId);
    } else {
      await service.addFavorite(channel);
    }
    ref.invalidate(favoritesProvider);
    ref.invalidate(favoriteIdsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFav
                ? '${channel.name} eliminado de favoritos'
                : '${channel.name} agregado a favoritos',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  Future<void> _hideChannel(XtreamChannel channel) async {
    await ref.read(hiddenChannelIdsProvider.notifier).hide(channel.streamId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${channel.name} ocultado'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  void _showChannelContextMenu(XtreamChannel channel, bool isFav) {
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (context) => _ChannelContextMenuDialog(
        channel: channel,
        isFavorite: isFav,
        onFavoriteToggle: () => _toggleFavorite(channel, isFav),
        onHide: () => _hideChannel(channel),
        onAddToGroup: (groupId) {
          // TODO: Implement add to group
        },
        groups: ref.read(customGroupsProvider).map((g) => g.name).toList(),
      ),
    ).then((_) => _isDialogOpen = false);
  }

  void _showCategoryContextMenu(XtreamCategory category, String displayName) {
    _isDialogOpen = true;
    final settings = ref
        .read(categorySettingsProvider.notifier)
        .getSettings(category.categoryId);
    showDialog(
      context: context,
      builder: (context) => _CategoryContextMenuDialog(
        category: category,
        displayName: displayName,
        settings: settings,
        onRename: (newName) {
          ref
              .read(categorySettingsProvider.notifier)
              .setCustomName(category.categoryId, newName);
        },
        onRestoreName: () {
          ref
              .read(categorySettingsProvider.notifier)
              .setCustomName(category.categoryId, null);
        },
        onSortOrderChanged: (order) {
          ref
              .read(categorySettingsProvider.notifier)
              .setSortOrder(category.categoryId, order);
        },
        onShowFavoritesOnlyChanged: (value) {
          ref
              .read(categorySettingsProvider.notifier)
              .setShowFavoritesOnly(category.categoryId, value);
        },
        onHide: () {
          ref
              .read(hiddenCategoryIdsProvider.notifier)
              .hide(category.categoryId);
        },
      ),
    ).then((_) => _isDialogOpen = false);
  }

  Future<void> _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('xtream_url');
    await prefs.remove('xtream_user');
    await prefs.remove('xtream_pass');
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _contentScrollController.dispose();
    _previewTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }
}

/// Context menu dialog for channel actions (D-pad compatible)
class _ChannelContextMenuDialog extends StatefulWidget {
  final XtreamChannel channel;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onHide;
  final Function(String) onAddToGroup;
  final List<String> groups;

  const _ChannelContextMenuDialog({
    required this.channel,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onHide,
    required this.onAddToGroup,
    required this.groups,
  });

  @override
  State<_ChannelContextMenuDialog> createState() =>
      _ChannelContextMenuDialogState();
}

class _ChannelContextMenuDialogState extends State<_ChannelContextMenuDialog> {
  int _selectedIndex = 0;
  late List<_MenuOption> _options;

  @override
  void initState() {
    super.initState();
    _options = [
      _MenuOption(
        icon: Icons.star,
        label: widget.isFavorite
            ? 'Quitar de favoritos'
            : 'Agregar a favoritos',
        onTap: widget.onFavoriteToggle,
      ),
      _MenuOption(
        icon: Icons.visibility_off,
        label: 'Ocultar canal',
        onTap: widget.onHide,
        isDestructive: true,
      ),
      if (widget.groups.isNotEmpty)
        _MenuOption(
          icon: Icons.folder,
          label: 'Agregar a grupo',
          onTap: () => _showGroupSubmenu(context),
          closesDialog: false,
        ),
      _MenuOption(
        icon: Icons.info_outline,
        label: 'Info del canal',
        onTap: () => _showChannelInfo(context),
        closesDialog: false,
      ),
    ];
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _options.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _options.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      final option = _options[_selectedIndex];
      option.onTap();
      if (option.closesDialog) {
        Navigator.pop(context);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: AlertDialog(
        backgroundColor: Colors.grey[900],
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with channel name
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            // Menu options
            ..._options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = index == _selectedIndex;

              return Container(
                color: isSelected
                    ? Colors.deepPurple.withValues(alpha: 0.5)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () {
                    option.onTap();
                    if (option.closesDialog) {
                      Navigator.pop(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          color: option.isDestructive
                              ? Colors.red
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.label,
                            style: TextStyle(
                              color: option.isDestructive
                                  ? Colors.red
                                  : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white54,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showGroupSubmenu(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => _GroupSubmenuDialog(
        groups: widget.groups,
        onSelect: widget.onAddToGroup,
      ),
    );
  }

  void _showChannelInfo(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => _ChannelInfoDialog(channel: widget.channel),
    );
  }
}

class _MenuOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool closesDialog;

  _MenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.closesDialog = true,
  });
}

/// Group selection submenu (D-pad compatible)
class _GroupSubmenuDialog extends StatefulWidget {
  final List<String> groups;
  final Function(String) onSelect;

  const _GroupSubmenuDialog({required this.groups, required this.onSelect});

  @override
  State<_GroupSubmenuDialog> createState() => _GroupSubmenuDialogState();
}

class _GroupSubmenuDialogState extends State<_GroupSubmenuDialog> {
  int _selectedIndex = 0;

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(
          0,
          widget.groups.length - 1,
        );
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(
          0,
          widget.groups.length - 1,
        );
      });
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      widget.onSelect(widget.groups[_selectedIndex]);
      Navigator.pop(context);
    } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Selecciona un grupo',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.groups.asMap().entries.map((entry) {
            final index = entry.key;
            final group = entry.value;
            final isSelected = index == _selectedIndex;

            return Container(
              color: isSelected
                  ? Colors.deepPurple.withValues(alpha: 0.5)
                  : Colors.transparent,
              child: ListTile(
                title: Text(group, style: const TextStyle(color: Colors.white)),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
                onTap: () {
                  widget.onSelect(group);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Channel info dialog (D-pad compatible)
class _ChannelInfoDialog extends StatelessWidget {
  final XtreamChannel channel;

  const _ChannelInfoDialog({required this.channel});

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          Navigator.pop(context);
        }
      },
      child: AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Información del canal',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Nombre', channel.name),
            _buildInfoRow('ID', channel.streamId.toString()),
            _buildInfoRow('Categoría', channel.categoryId),
            _buildInfoRow('Tipo', channel.streamType),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Category context menu dialog (D-pad compatible)
class _CategoryContextMenuDialog extends StatefulWidget {
  final XtreamCategory category;
  final String displayName;
  final CategorySettings settings;
  final Function(String) onRename;
  final VoidCallback onRestoreName;
  final Function(ChannelSortOrder) onSortOrderChanged;
  final Function(bool) onShowFavoritesOnlyChanged;
  final VoidCallback onHide;

  const _CategoryContextMenuDialog({
    required this.category,
    required this.displayName,
    required this.settings,
    required this.onRename,
    required this.onRestoreName,
    required this.onSortOrderChanged,
    required this.onShowFavoritesOnlyChanged,
    required this.onHide,
  });

  @override
  State<_CategoryContextMenuDialog> createState() =>
      _CategoryContextMenuDialogState();
}

class _CategoryContextMenuDialogState
    extends State<_CategoryContextMenuDialog> {
  int _selectedIndex = 0;
  late ChannelSortOrder _sortOrder;
  late bool _showFavoritesOnly;

  final List<String> _menuLabels = [
    'Nombre del grupo',
    'Restaurar nombre',
    'Ordenar canales',
    'Solo favoritos',
    'Ocultar grupo',
  ];

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.settings.sortOrder;
    _showFavoritesOnly = widget.settings.showFavoritesOnly;
  }

  String _getSortOrderLabel() {
    switch (_sortOrder) {
      case ChannelSortOrder.playlist:
        return 'Por playlist';
      case ChannelSortOrder.nameAsc:
        return 'A-Z';
      case ChannelSortOrder.nameDesc:
        return 'Z-A';
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _menuLabels.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _menuLabels.length - 1);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _handleSelect();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _handleLeftRight(event.logicalKey == LogicalKeyboardKey.arrowRight);
    } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
  }

  void _handleSelect() {
    switch (_selectedIndex) {
      case 0: // Nombre del grupo
        _showRenameDialog();
        break;
      case 1: // Restaurar nombre
        widget.onRestoreName();
        Navigator.pop(context);
        break;
      case 2: // Ordenar canales - cycle through options
        _cycleSortOrder();
        break;
      case 3: // Solo favoritos - toggle
        setState(() {
          _showFavoritesOnly = !_showFavoritesOnly;
        });
        widget.onShowFavoritesOnlyChanged(_showFavoritesOnly);
        break;
      case 4: // Ocultar grupo
        widget.onHide();
        Navigator.pop(context);
        break;
    }
  }

  void _handleLeftRight(bool isRight) {
    if (_selectedIndex == 2) {
      // Sort order
      _cycleSortOrder(forward: isRight);
    } else if (_selectedIndex == 3) {
      // Favorites toggle
      setState(() {
        _showFavoritesOnly = !_showFavoritesOnly;
      });
      widget.onShowFavoritesOnlyChanged(_showFavoritesOnly);
    }
  }

  void _cycleSortOrder({bool forward = true}) {
    final orders = ChannelSortOrder.values;
    final currentIdx = orders.indexOf(_sortOrder);
    final newIdx = forward
        ? (currentIdx + 1) % orders.length
        : (currentIdx - 1 + orders.length) % orders.length;
    setState(() {
      _sortOrder = orders[newIdx];
    });
    widget.onSortOrderChanged(_sortOrder);
  }

  void _showRenameDialog() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => _RenameDialog(
        currentName: widget.displayName,
        originalName: widget.category.categoryName,
        onSave: widget.onRename,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: AlertDialog(
        backgroundColor: Colors.grey[900],
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Text(
                  widget.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Menu items
              _buildMenuItem(0, 'Nombre del grupo', widget.displayName),
              _buildMenuItem(
                1,
                'Restaurar nombre',
                widget.category.categoryName,
                isSubtle: true,
              ),
              _buildMenuItem(
                2,
                'Ordenar canales',
                _getSortOrderLabel(),
                hasArrows: true,
              ),
              _buildToggleItem(3, 'Solo favoritos', _showFavoritesOnly),
              _buildMenuItem(4, 'Ocultar grupo', null, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    int index,
    String label,
    String? value, {
    bool isSubtle = false,
    bool hasArrows = false,
    bool isDestructive = false,
  }) {
    final isSelected = index == _selectedIndex;

    return Container(
      color: isSelected
          ? Colors.deepPurple.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          _handleSelect();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isDestructive ? Colors.red : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (value != null)
                      Text(
                        value,
                        style: TextStyle(
                          color: isSubtle
                              ? Colors.white38
                              : Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasArrows && isSelected) ...[
                const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem(int index, String label, bool value) {
    final isSelected = index == _selectedIndex;

    return Container(
      color: isSelected
          ? Colors.deepPurple.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          _handleSelect();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: (v) {
                  setState(() {
                    _showFavoritesOnly = v;
                  });
                  widget.onShowFavoritesOnlyChanged(v);
                },
                activeTrackColor: Colors.deepPurple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rename dialog for category
class _RenameDialog extends StatefulWidget {
  final String currentName;
  final String originalName;
  final Function(String) onSave;

  const _RenameDialog({
    required this.currentName,
    required this.originalName,
    required this.onSave,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text(
        'Renombrar grupo',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: widget.originalName,
          hintStyle: const TextStyle(color: Colors.white38),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.deepPurple),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.onSave(name);
            }
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
