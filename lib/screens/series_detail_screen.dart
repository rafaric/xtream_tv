import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../providers/xtream_provider.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends ConsumerStatefulWidget {
  final Series series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  final ScrollController _episodesScrollController = ScrollController();
  final Map<int, GlobalKey> _episodeKeys = {};
  final FocusNode _keyboardFocusNode = FocusNode();

  String _selectedSeason = '';
  int _seasonFocusIndex = 0;
  int _selectedEpisodeIndex = 0;

  // 0=Volver, 1=Temporadas, 2=Episodios
  int _focusColumn = 1; // Default focus en las temporadas

  @override
  void initState() {
    super.initState();
    _requestFocus();
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _episodesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episodesAsync = ref.watch(
      seriesEpisodesProvider(widget.series.seriesId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;

          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() {
              if (_focusColumn == 2) {
                if (_selectedEpisodeIndex > 0) {
                  _selectedEpisodeIndex--;
                  _scrollEpisodeToSelected();
                } else {
                  _focusColumn = 1; // Volver a las temporadas
                }
              } else if (_focusColumn > 0) {
                _focusColumn--;
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final episodes = _getCurrentEpisodes();
            setState(() {
              if (_focusColumn == 2) {
                if (_selectedEpisodeIndex < episodes.length - 1) {
                  _selectedEpisodeIndex++;
                  _scrollEpisodeToSelected();
                }
              } else if (_focusColumn < 2) {
                _focusColumn++;
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (_focusColumn == 1 && _seasonFocusIndex > 0) {
              setState(() {
                _seasonFocusIndex--;
                _episodeKeys.clear();
                _selectedEpisodeIndex = 0;
              });
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (_focusColumn == 1) {
              final seasons = _getCurrentSeasons();
              if (_seasonFocusIndex < seasons.length - 1) {
                setState(() {
                  _seasonFocusIndex++;
                  _episodeKeys.clear();
                  _selectedEpisodeIndex = 0;
                });
              }
            }
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _handleSelect();
          }
        },
        child: Stack(
          children: [
            // Fondo difuminado
            if (widget.series.cover.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: Image.network(
                    widget.series.cover,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const SizedBox(),
                  ),
                ),
              ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0D0D1A).withValues(alpha: 0.6),
                      const Color(0xFF0D0D1A),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.series.cover.isNotEmpty
                          ? Image.network(
                              widget.series.cover,
                              width: 200,
                              height: 290,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),

                  // Info + episodios
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 32, 32, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNavButton(
                            text: 'Volver',
                            icon: Icons.arrow_back,
                            isFocused: _focusColumn == 0,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 8),

                          // Título
                          Text(
                            widget.series.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Metadata
                          Wrap(
                            spacing: 16,
                            children: [
                              if (widget.series.genre.isNotEmpty)
                                _buildBadge(
                                  Icons.category,
                                  widget.series.genre,
                                ),
                              if (widget.series.rating > 0)
                                _buildBadge(
                                  Icons.star,
                                  widget.series.rating.toStringAsFixed(1),
                                  color: Colors.amber,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Sinopsis
                          if (widget.series.plot.isNotEmpty)
                            Text(
                              widget.series.plot,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),

                          const SizedBox(height: 20),

                          // Episodios
                          Expanded(
                            child: episodesAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.deepPurple,
                                ),
                              ),
                              error: (e, _) => Text(
                                'Error: $e',
                                style: const TextStyle(color: Colors.red),
                              ),
                              data: (seasons) => _buildEpisodesSection(seasons),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesSection(Map<String, List<SeriesEpisode>> seasons) {
    if (seasons.isEmpty) {
      return const Text(
        'No hay episodios disponibles',
        style: TextStyle(color: Colors.white38),
      );
    }

    final seasonKeys = _getCurrentSeasons();
    if (_seasonFocusIndex >= seasonKeys.length) {
      _seasonFocusIndex = seasonKeys.isNotEmpty ? seasonKeys.length - 1 : 0;
    }
    if (seasonKeys.isNotEmpty) {
      _selectedSeason = seasonKeys[_seasonFocusIndex];
    }

    final episodes = _getCurrentEpisodes();
    if (_selectedEpisodeIndex >= episodes.length) {
      _selectedEpisodeIndex = episodes.isNotEmpty ? episodes.length - 1 : 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de temporadas
        const Text(
          'TEMPORADA',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: seasonKeys.asMap().entries.map((entry) {
              final index = entry.key;
              final season = entry.value;
              final isFocused = _focusColumn == 1 && index == _seasonFocusIndex;
              return GestureDetector(
                onTap: () => setState(() {
                  _seasonFocusIndex = index;
                  _selectedEpisodeIndex = 0;
                  _episodeKeys.clear();
                  _focusColumn = 1;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? Colors.deepPurple
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFocused
                          ? Colors.deepPurpleAccent
                          : Colors.deepPurple.withValues(alpha: 0.3),
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    'T$season',
                    style: TextStyle(
                      color: isFocused ? Colors.white : Colors.white54,
                      fontWeight: isFocused
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Lista de episodios
        const Text(
          'EPISODIOS',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: episodes.isEmpty
              ? const Center(
                  child: Text(
                    "No hay episodios en esta temporada.",
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  controller: _episodesScrollController,
                  itemCount: episodes.length,
                  itemBuilder: (context, index) {
                    _episodeKeys.putIfAbsent(index, () => GlobalKey());
                    final ep = episodes[index];
                    final isFocused =
                        _focusColumn == 2 && index == _selectedEpisodeIndex;
                    return GestureDetector(
                      key: _episodeKeys[index],
                      onTap: () => _playEpisode(ep),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? Colors.deepPurple
                              : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFocused
                                ? Colors.deepPurpleAccent
                                : Colors.deepPurple.withValues(alpha: 0.2),
                            width: isFocused ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${ep.episodeNum}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ep.title,
                                    style: TextStyle(
                                      color: isFocused
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: isFocused
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (ep.plot.isNotEmpty)
                                    Text(
                                      ep.plot,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (isFocused)
                              const Icon(
                                Icons.play_circle_outline,
                                color: Colors.deepPurpleAccent,
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _handleSelect() {
    if (_focusColumn == 0) {
      Navigator.of(context).pop();
    } else if (_focusColumn == 1) {
      setState(() => _focusColumn = 2);
    } else if (_focusColumn == 2) {
      final episodes = _getCurrentEpisodes();
      if (_selectedEpisodeIndex < episodes.length) {
        _playEpisode(episodes[_selectedEpisodeIndex]);
      }
    }
  }

  List<String> _getCurrentSeasons() {
    final episodesAsync = ref.read(
      seriesEpisodesProvider(widget.series.seriesId),
    );
    return episodesAsync.maybeWhen(
      data: (s) => s.keys.toList(),
      orElse: () => [],
    );
  }

  List<SeriesEpisode> _getCurrentEpisodes() {
    final episodesAsync = ref.read(
      seriesEpisodesProvider(widget.series.seriesId),
    );
    final seasons = episodesAsync.maybeWhen(data: (s) => s, orElse: () => {});
    return seasons[_selectedSeason] ?? [];
  }

  void _scrollEpisodeToSelected() {
    final key = _episodeKeys[_selectedEpisodeIndex];
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          alignment: 0.5, // Centrar
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _playEpisode(SeriesEpisode episode) async {
    final service = ref.read(xtreamServiceProvider);
    final url = episode.directSource.isNotEmpty
        ? episode.directSource
        : service.getEpisodeUrl(episode.id, episode.containerExtension);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: XtreamChannel(
            streamId: episode.id,
            name:
                '${widget.series.name} · T${episode.season} E${episode.episodeNum}',
            streamIcon: widget.series.cover,
            categoryId: widget.series.categoryId,
            streamType: 'series',
          ),
          streamUrl: url,
        ),
      ),
    );

    // Re-request focus after returning from player to ensure back button works
    _requestFocus();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 200,
      height: 290,
      color: const Color(0xFF1A1A2E),
      child: const Icon(
        Icons.video_library,
        color: Colors.deepPurple,
        size: 64,
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.white54),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color ?? Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required String text,
    required IconData icon,
    required bool isFocused,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isFocused
            ? Colors.deepPurple.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFocused ? Colors.deepPurpleAccent : Colors.transparent,
          width: 1,
        ),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: isFocused ? Colors.white : Colors.white54),
        label: Text(
          text,
          style: TextStyle(color: isFocused ? Colors.white : Colors.white54),
        ),
      ),
    );
  }
}
