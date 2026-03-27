import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/xtream_provider.dart';
import '../models/channel.dart';
import 'login_screen.dart';
import 'player_screen.dart';
import 'vod_detail_screen.dart';
import 'series_detail_screen.dart';
import 'groups_screen.dart';
import '../widgets/channel_preview.dart';
import 'dart:async';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedContentIndex = 0;
  int _focusColumn = 1; // 0=nav, 1=categorías, 2=contenido
  XtreamChannel? _previewChannel;
  EpgProgram? _previewProgram;
  Timer? _previewTimer;
  Player? _previewPlayer;
  VideoController? _previewController;
  bool _playerScreenOpen = false;

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
              children: _navItems.map((item) {
                final isSelected = currentSection == item['section'];
                final isFocused =
                    _focusColumn == 0 &&
                    _navItems.indexOf(item) == _selectedCategoryIndex;
                return _buildNavItem(
                  icon: item['icon'] as IconData,
                  label: item['label'] as String,
                  isSelected: isSelected,
                  isFocused: isFocused,
                  onTap: () {
                    ref.read(mainSectionProvider.notifier).state =
                        item['section'] as MainSection;
                    setState(() {
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
    final allCategories = [
      XtreamCategory(categoryId: '__all__', categoryName: 'Todos'),
      ...categories,
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
              final isSelected = index == _selectedCategoryIndex;
              final isFocused = _focusColumn == 1 && isSelected;
              return _buildCategoryItem(
                allCategories[index],
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
          category.categoryName,
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
        final allCategories = [
          XtreamCategory(categoryId: '__all__', categoryName: 'Todos'),
          ...categories,
        ];
        if (_selectedCategoryIndex >= allCategories.length) {
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
    if (channels.isEmpty) {
      return _buildEmptyWidget('No hay canales en esta categoría');
    }
    final epgMapAsync = ref.watch(epgMapProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider);

    return epgMapAsync.when(
      loading: () => _buildChannelList(channels, {}, favoriteIds),
      error: (e, _) => _buildChannelList(channels, {}, favoriteIds),
      data: (epgMap) => _buildChannelList(channels, epgMap, favoriteIds),
    );
  }

  Widget _buildChannelList(
    List<XtreamChannel> channels,
    Map<String, EpgProgram?> epgMap,
    AsyncValue<Set<int>> favoriteIds,
  ) {
    return Column(
      children: [
        // Preview del canal seleccionado
        if (_previewChannel != null && _previewController != null)
          ChannelPreview(
            key: ValueKey(_previewChannel!.streamId),
            channel: _previewChannel!,
            controller: _previewController!,
            currentProgram: _previewProgram,
          ),

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
      onLongPress: () => _toggleFavorite(channel, isFav),
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
      onLongPress: () => _toggleFavorite(channel, isFav),
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

  void _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_focusColumn > 0) setState(() => _focusColumn--);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_focusColumn < 2) setState(() => _focusColumn++);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _navigateUp();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _navigateDown();
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _handleSelect();
    }
  }

  void _navigateUp() {
    setState(() {
      if (_focusColumn == 0 || _focusColumn == 1) {
        if (_selectedCategoryIndex > 0) _selectedCategoryIndex--;
        _scrollCategoryToSelected();
      } else {
        if (_selectedContentIndex > 0) _selectedContentIndex--;
        _scrollContentToSelected();
      }
    });
  }

  void _navigateDown() {
    setState(() {
      if (_focusColumn == 0 || _focusColumn == 1) {
        _selectedCategoryIndex++;
        _scrollCategoryToSelected();
      } else {
        _selectedContentIndex++;
        _scrollContentToSelected();
      }
    });
  }

  void _handleSelect() {
    if (_focusColumn == 0) {
      final section =
          _navItems[_selectedCategoryIndex % _navItems.length]['section']
              as MainSection;
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
      if (_selectedContentIndex < channels.length) {
        _openLivePlayer(channels[_selectedContentIndex]);
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
      ...categories,
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
    const itemHeight = 72.0;
    final offset = _selectedContentIndex * itemHeight;
    if (_contentScrollController.hasClients) {
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
        final groupChannels = allChannels
            .where((c) => selectedGroup.channelIds.contains(c.streamId))
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
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final service = ref.read(xtreamServiceProvider);
      final url = service.getStreamUrl(channel.streamId);
      final program = _findEpgForChannel(channel.name, epgMap);
      // Dispose previous preview player and create a new one
      _previewPlayer?.dispose();
      final player = Player();
      final controller = VideoController(player);
      player.open(Media(url));
      setState(() {
        _previewPlayer = player;
        _previewController = controller;
        _previewChannel = channel;
        _previewProgram = program;
      });
    });
  }

  // ignore: unused_element
  void _clearPreview() {
    _previewTimer?.cancel();
    _previewPlayer?.dispose();
    _previewPlayer = null;
    _previewController = null;
    setState(() {
      _previewChannel = null;
      _previewProgram = null;
    });
  }

  void _openLivePlayer(XtreamChannel channel) {
    final service = ref.read(xtreamServiceProvider);
    final epgMap = ref
        .read(epgMapProvider)
        .maybeWhen(data: (map) => map, orElse: () => <String, EpgProgram?>{});

    // Obtener canales de la categoría actual
    final categoriesAsync = ref.read(categoriesProvider);
    final categories = categoriesAsync.maybeWhen(
      data: (cats) => cats,
      orElse: () => <XtreamCategory>[],
    );
    final allCategories = [
      XtreamCategory(categoryId: '__all__', categoryName: 'Todos'),
      ...categories,
    ];
    final selectedCategory = _selectedCategoryIndex < allCategories.length
        ? allCategories[_selectedCategoryIndex]
        : null;
    final categoryId = selectedCategory?.categoryId == '__all__'
        ? null
        : selectedCategory?.categoryId;

    final channelsAsync = ref.read(channelsProvider(categoryId ?? '__all__'));
    final categoryChannels = channelsAsync.maybeWhen(
      data: (ch) => ch,
      orElse: () => <XtreamChannel>[],
    );

    // Reusar el preview player si es el mismo canal, o crear uno nuevo
    Player? existingPlayer;
    VideoController? existingController;
    if (_previewChannel?.streamId == channel.streamId &&
        _previewPlayer != null) {
      existingPlayer = _previewPlayer;
      existingController = _previewController;
    } else {
      // Descartar preview de otro canal
      _previewPlayer?.dispose();
    }

    // Limpiar preview sin dispose (PlayerScreen toma ownership)
    _previewTimer?.cancel();
    _previewPlayer = null;
    _previewController = null;
    _playerScreenOpen = true;
    setState(() {
      _previewChannel = null;
      _previewProgram = null;
    });

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              channel: channel,
              streamUrl: service.getStreamUrl(channel.streamId),
              categoryChannels: categoryChannels,
              epgMap: epgMap,
              player: existingPlayer,
              controller: existingController,
            ),
          ),
        )
        .then((_) => _playerScreenOpen = false);
  }

  void _openVodDetail(VodStream vod) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => VodDetailScreen(vod: vod)));
  }

  void _openSeriesDetail(Series series) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)),
    );
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
    _previewPlayer?.dispose();
    super.dispose();
  }
}
