import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../providers/xtream_provider.dart';
import 'player_screen.dart';

class VodDetailScreen extends ConsumerStatefulWidget {
  final VodStream vod;

  const VodDetailScreen({super.key, required this.vod});

  @override
  ConsumerState<VodDetailScreen> createState() => _VodDetailScreenState();
}

class _VodDetailScreenState extends ConsumerState<VodDetailScreen> {
  int _focusedButtonIndex = 1; // 0=Volver, 1=Reproducir (default)

  @override
  Widget build(BuildContext context) {
    final service = ref.read(xtreamServiceProvider);
    final vod = widget.vod;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;

          if (event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() {
              if (_focusedButtonIndex > 0) _focusedButtonIndex--;
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              if (_focusedButtonIndex < 1) _focusedButtonIndex++;
            });
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _handleSelect();
          }
        },
        child: Stack(
          children: [
            // Fondo con poster difuminado
            if (vod.streamIcon.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: Image.network(
                    vod.streamIcon,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const SizedBox(),
                  ),
                ),
              ),

            // Gradiente sobre el fondo
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0D0D1A).withOpacity(0.6),
                      const Color(0xFF0D0D1A),
                    ],
                  ),
                ),
              ),
            ),

            // Contenido
            SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: vod.streamIcon.isNotEmpty
                          ? Image.network(
                              vod.streamIcon,
                              width: 220,
                              height: 320,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  _buildPosterPlaceholder(),
                            )
                          : _buildPosterPlaceholder(),
                    ),
                  ),

                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 32, 32, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNavButton(
                            text: 'Volver',
                            icon: Icons.arrow_back,
                            isFocused: _focusedButtonIndex == 0,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 16),

                          // Título
                          Text(
                            vod.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Metadata
                          Wrap(
                            spacing: 16,
                            children: [
                              if (vod.releaseDate.isNotEmpty)
                                _buildBadge(
                                  Icons.calendar_today,
                                  vod.releaseDate,
                                ),
                              if (vod.genre.isNotEmpty)
                                _buildBadge(Icons.category, vod.genre),
                              if (vod.rating > 0)
                                _buildBadge(
                                  Icons.star,
                                  vod.rating.toStringAsFixed(1),
                                  color: Colors.amber,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Sinopsis
                          if (vod.plot.isNotEmpty) ...[
                            const Text(
                              'Sinopsis',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              vod.plot,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                                height: 1.6,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Director / Cast
                          if (vod.director.isNotEmpty)
                            _buildInfoRow('Director', vod.director),
                          if (vod.cast.isNotEmpty)
                            _buildInfoRow('Reparto', vod.cast),

                          const Spacer(),

                          // Botón reproducir
                          _buildPlayButton(
                            isFocused: _focusedButtonIndex == 1,
                            onPressed: () {
                              final url = service.getVodUrl(
                                vod.streamId,
                                vod.containerExtension,
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    channel: XtreamChannel(
                                      streamId: vod.streamId,
                                      name: vod.name,
                                      streamIcon: vod.streamIcon,
                                      categoryId: vod.categoryId,
                                      streamType: 'movie',
                                    ),
                                    streamUrl: url,
                                  ),
                                ),
                              );
                            },
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

  Widget _buildPosterPlaceholder() {
    return Container(
      width: 220,
      height: 320,
      color: const Color(0xFF1A1A2E),
      child: const Icon(Icons.movie, color: Colors.deepPurple, size: 64),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _handleSelect() {
    if (_focusedButtonIndex == 0) {
      // Volver
      Navigator.of(context).pop();
    } else if (_focusedButtonIndex == 1) {
      // Reproducir
      final service = ref.read(xtreamServiceProvider);
      final vod = widget.vod;
      final url = service.getVodUrl(vod.streamId, vod.containerExtension);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            channel: XtreamChannel(
              streamId: vod.streamId,
              name: vod.name,
              streamIcon: vod.streamIcon,
              categoryId: vod.categoryId,
              streamType: 'movie',
            ),
            streamUrl: url,
          ),
        ),
      );
    }
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
            ? Colors.deepPurple.withOpacity(0.3)
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

  Widget _buildPlayButton({
    required bool isFocused,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 200,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.7),
                    blurRadius: 12,
                  ),
                ]
              : [],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.play_arrow, size: 28),
          label: const Text(
            'Reproducir',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isFocused ? Colors.deepPurpleAccent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
