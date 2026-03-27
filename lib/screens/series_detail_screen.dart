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
  String _selectedSeason = '';
  int _selectedEpisodeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final episodesAsync = ref.watch(
      seriesEpisodesProvider(widget.series.seriesId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
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
                          // Volver
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white54,
                            ),
                            label: const Text(
                              'Volver',
                              style: TextStyle(color: Colors.white54),
                            ),
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

    // Inicializar temporada seleccionada
    if (_selectedSeason.isEmpty) {
      _selectedSeason = seasons.keys.first;
    }

    final episodes = seasons[_selectedSeason] ?? [];

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
            children: seasons.keys.map((season) {
              final isSelected = season == _selectedSeason;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedSeason = season;
                  _selectedEpisodeIndex = 0;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurple
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.deepPurple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'T$season',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: isSelected
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
          child: ListView.builder(
            itemCount: episodes.length,
            itemBuilder: (context, index) {
              final ep = episodes[index];
              final isSelected = index == _selectedEpisodeIndex;
              return GestureDetector(
                onTap: () => _playEpisode(ep),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.deepPurple
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.deepPurpleAccent
                          : Colors.deepPurple.withValues(alpha: 0.2),
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
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: isSelected
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

  void _playEpisode(SeriesEpisode episode) {
    final service = ref.read(xtreamServiceProvider);

    // Usar direct_source si está disponible, sino construir la URL
    final url = episode.directSource.isNotEmpty
        ? episode.directSource
        : service.getEpisodeUrl(episode.id, episode.containerExtension);

    Navigator.of(context).push(
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
}
