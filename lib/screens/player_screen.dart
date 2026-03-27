import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/channel.dart';
import '../providers/xtream_provider.dart';
import '../widgets/channel_history_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final XtreamChannel channel;
  final String streamUrl;
  final List<XtreamChannel> categoryChannels;
  final Map<String, EpgProgram?> epgMap;
  final Player? player;
  final VideoController? controller;

  const PlayerScreen({
    super.key,
    required this.channel,
    required this.streamUrl,
    this.categoryChannels = const [],
    this.epgMap = const {},
    this.player,
    this.controller,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late Player _player;
  late VideoController _controller;
  bool _ownsPlayer = false;
  bool _showOverlay = true;
  bool _isBuffering = true;
  bool _isDisposed = false;
  bool _showEpgPanel = false;
  int _epgPanelChannelIndex = 0;
  late XtreamChannel _currentChannel;
  late String _currentStreamUrl;
  final _epgChannelScrollController = ScrollController();
  bool _showHistoryOverlay = false;
  EpgProgram? _currentEpgProgram;

  // Estado de error del stream
  String? _streamError;

  // Key para forzar rebuild del Video widget en web
  Key _videoKey = UniqueKey();

  // Menú de opciones (long press en botón central)
  bool _showOptionsMenu = false;
  int _selectedMenuIndex = 0;
  Timer? _longPressTimer;
  bool _isLongPress = false;

  // Buffering timeout y auto-retry
  Timer? _bufferingTimeoutTimer;
  int _retryCount = 0;
  static const int _maxRetries = 1;
  static const Duration _bufferingTimeout = Duration(seconds: 15);

  StreamSubscription<bool>? _bufferingSubscription;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _currentStreamUrl = widget.streamUrl;

    if (widget.player != null && widget.controller != null) {
      // Reusar player del preview — ya está reproduciendo
      _player = widget.player!;
      _controller = widget.controller!;
      _ownsPlayer = true;
      _isBuffering = _player.state.buffering;
      _bufferingSubscription = _player.stream.buffering.listen((buffering) {
        if (mounted && !_isDisposed) setState(() => _isBuffering = buffering);
      });
    } else {
      _ownsPlayer = true;
      _player = Player();
      _controller = VideoController(_player);
      _initPlayer();
    }

    // Inicializar índice en el canal actual
    final idx = widget.categoryChannels.indexWhere(
      (c) => c.streamId == _currentChannel.streamId,
    );
    if (idx != -1) _epgPanelChannelIndex = idx;

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOverlay = false);
    });

    HardwareKeyboard.instance.addHandler(_onKey);
  }

  StreamSubscription<String>? _errorSubscription;

  Future<void> _initPlayer({String? url}) async {
    if (_isDisposed) return;

    final streamUrl = url ?? _currentStreamUrl;

    // Solo configurar listeners una vez (en el primer init)
    if (_bufferingSubscription == null) {
      _setupPlayerListeners();
    }

    await _player.open(Media(streamUrl));
  }

  void _setupPlayerListeners() {
    _bufferingSubscription?.cancel();
    _errorSubscription?.cancel();

    _bufferingSubscription = _player.stream.buffering.listen((buffering) {
      if (mounted && !_isDisposed) {
        setState(() => _isBuffering = buffering);

        if (buffering) {
          // Iniciar timeout cuando empieza a bufferear
          _startBufferingTimeout();
        } else {
          // Cancelar timeout y resetear retry cuando reproduce bien
          _cancelBufferingTimeout();
          _retryCount = 0;
        }
      }
    });

    // Escuchar errores del stream
    _errorSubscription = _player.stream.error.listen((error) {
      debugPrint('🔴 Player error: $error');
      if (mounted && !_isDisposed) {
        // Detectar errores de stream no disponible
        if (error.contains('CHUNK_DEMUXER_ERROR') ||
            error.contains('PIPELINE_ERROR') ||
            error.contains('MEDIA_ERR') ||
            error.contains('parsing failed') ||
            error.contains('404') ||
            error.contains('network')) {
          _handleStreamError();
        }
      }
    });
  }

  void _startBufferingTimeout() {
    _cancelBufferingTimeout();
    _bufferingTimeoutTimer = Timer(_bufferingTimeout, () {
      if (mounted && !_isDisposed && _isBuffering) {
        debugPrint(
          '⏱️ Buffering timeout after ${_bufferingTimeout.inSeconds}s',
        );
        _handleStreamError();
      }
    });
  }

  void _cancelBufferingTimeout() {
    _bufferingTimeoutTimer?.cancel();
    _bufferingTimeoutTimer = null;
  }

  void _handleStreamError() {
    _cancelBufferingTimeout();

    if (_retryCount < _maxRetries) {
      // Auto-retry
      _retryCount++;
      debugPrint('🔄 Auto-retry $_retryCount/$_maxRetries');
      _retryCurrentChannel();
    } else {
      // Mostrar error después de agotar retries
      debugPrint('❌ Max retries reached, showing error');
      setState(() {
        _streamError = 'Canal no disponible';
        _isBuffering = false;
      });
    }
  }

  Future<void> _retryCurrentChannel() async {
    debugPrint('🔄 Retrying channel: ${_currentChannel.name}');

    if (kIsWeb) {
      // En Web: recrear player
      _bufferingSubscription?.cancel();
      _errorSubscription?.cancel();
      await _player.dispose();

      _player = Player();
      _controller = VideoController(_player);

      setState(() {
        _videoKey = UniqueKey();
        _isBuffering = true;
        _streamError = null;
      });

      _setupPlayerListeners();
      await _player.open(Media(_currentStreamUrl));
    } else {
      // En otras plataformas: solo reabrir
      setState(() {
        _isBuffering = true;
        _streamError = null;
      });
      await _player.open(Media(_currentStreamUrl));
    }
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
  }

  Future<void> _switchChannel(XtreamChannel channel) async {
    ref.read(historyProvider.notifier).add(_currentChannel);
    final service = ref.read(xtreamServiceProvider);
    final url = service.getStreamUrl(channel.streamId);

    debugPrint('🔄 Switching channel to: ${channel.name}');
    debugPrint('🔗 URL: $url');

    // Resetear estado de retry y timeout
    _cancelBufferingTimeout();
    _retryCount = 0;

    setState(() {
      _currentChannel = channel;
      _currentStreamUrl = url;
      _isBuffering = true;
      _streamError = null; // Limpiar error anterior
      _showEpgPanel = false;
      _showOverlay = true;
    });

    // En Web: recrear el VideoController para forzar nuevo elemento <video>
    if (kIsWeb) {
      debugPrint('🌐 Web: recreating VideoController...');

      // Limpiar subscriptions antes de recrear
      _bufferingSubscription?.cancel();
      _errorSubscription?.cancel();

      // Disponer el player anterior
      await _player.dispose();

      // Crear nuevo player y controller
      _player = Player();
      _controller = VideoController(_player);

      // Forzar rebuild del widget Video con nueva key
      setState(() {
        _videoKey = UniqueKey();
      });

      // Configurar listeners de nuevo
      _setupPlayerListeners();

      // Abrir el stream
      await _player.open(Media(url));
    } else {
      // En otras plataformas: solo abrir el nuevo media
      await _player.open(Media(url));
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _goBack() {
    if (_isDisposed) return;
    _isDisposed = true;
    _bufferingSubscription?.cancel();
    if (_ownsPlayer) _player.dispose();
    Navigator.of(context).pop();
  }

  bool _onKey(KeyEvent event) {
    if (!mounted) return false;

    final isSelectKey =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter;

    // ─────────────────────────────────────────────────────────────
    // LONG PRESS DETECTION para botón central
    // ─────────────────────────────────────────────────────────────
    if (isSelectKey &&
        !_showHistoryOverlay &&
        !_showEpgPanel &&
        !_showOptionsMenu) {
      if (event is KeyDownEvent) {
        _isLongPress = false;
        _longPressTimer?.cancel();
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            _isLongPress = true;
            setState(() {
              _showOptionsMenu = true;
              _selectedMenuIndex = 0;
            });
          }
        });
        return true;
      } else if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (!_isLongPress) {
          // Short press: toggle overlay
          _toggleOverlay();
        }
        _isLongPress = false;
        return true;
      }
    }

    // Solo procesar KeyDownEvent para el resto de teclas
    if (event is! KeyDownEvent) return false;

    // ─────────────────────────────────────────────────────────────
    // MENÚ DE OPCIONES
    // ─────────────────────────────────────────────────────────────
    if (_showOptionsMenu) {
      return _handleOptionsMenuKey(event);
    }

    // ─────────────────────────────────────────────────────────────
    // HISTORY OVERLAY (maneja sus propias teclas)
    // ─────────────────────────────────────────────────────────────
    if (_showHistoryOverlay) return false;

    // ─────────────────────────────────────────────────────────────
    // EPG PANEL
    // ─────────────────────────────────────────────────────────────
    if (_showEpgPanel) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_epgPanelChannelIndex < widget.categoryChannels.length - 1) {
          setState(() => _epgPanelChannelIndex++);
          _scrollEpgToSelected();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_epgPanelChannelIndex > 0) {
          setState(() => _epgPanelChannelIndex--);
          _scrollEpgToSelected();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_epgPanelChannelIndex < widget.categoryChannels.length) {
          _switchChannel(widget.categoryChannels[_epgPanelChannelIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _showEpgPanel = false);
      }
      return true;
    }

    // ─────────────────────────────────────────────────────────────
    // NAVEGACIÓN PRINCIPAL DEL PLAYER
    // ─────────────────────────────────────────────────────────────
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _showHistoryOverlay = true);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (widget.categoryChannels.isNotEmpty) {
        setState(() => _showEpgPanel = true);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _goBack();
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _toggleOverlay();
    } else {
      return false;
    }
    return true;
  }

  void _showAudioTrackDialog() {
    final tracks = _player.state.tracks.audio;
    if (tracks.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => _buildTrackDialog(
        title: 'Pista de Audio',
        tracks: tracks
            .map((t) => t.title ?? t.language ?? 'Track ${t.id}')
            .toList(),
        selectedIndex: tracks.indexWhere(
          (t) => t.id == _player.state.track.audio.id,
        ),
        onSelect: (index) {
          _player.setAudioTrack(tracks[index]);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSubtitleTrackDialog() {
    final tracks = _player.state.tracks.subtitle;

    showDialog(
      context: context,
      builder: (context) => _buildTrackDialog(
        title: 'Subtítulos',
        tracks: [
          'Desactivados',
          ...tracks.map((t) => t.title ?? t.language ?? 'Track ${t.id}'),
        ],
        selectedIndex: _player.state.track.subtitle.id == 'no'
            ? 0
            : tracks.indexWhere(
                    (t) => t.id == _player.state.track.subtitle.id,
                  ) +
                  1,
        onSelect: (index) {
          if (index == 0) {
            _player.setSubtitleTrack(SubtitleTrack.no());
          } else {
            _player.setSubtitleTrack(tracks[index - 1]);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildTrackDialog({
    required String title,
    required List<String> tracks,
    required int selectedIndex,
    required void Function(int) onSelect,
  }) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...tracks.asMap().entries.map((entry) {
              final isSelected = entry.key == selectedIndex;
              return InkWell(
                onTap: () => onSelect(entry.key),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (isSelected)
                        const Icon(Icons.check, color: Colors.white, size: 20)
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 12),
                      Text(
                        entry.value,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _scrollEpgToSelected() {
    const itemHeight = 64.0;
    _epgChannelScrollController.animateTo(
      _epgPanelChannelIndex * itemHeight,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showOverlay ? null : _toggleOverlay,
        child: Stack(
          children: [
            // Video (key forces rebuild on channel switch in web)
            Center(
              child: Video(key: _videoKey, controller: _controller),
            ),

            // Buffering
            if (_isBuffering && _streamError == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Error de stream
            if (_streamError != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.signal_wifi_off,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _streamError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Probá con otro canal o intentá más tarde',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              // Reintentar el canal actual (resetear retry count)
                              _retryCount = 0;
                              _retryCurrentChannel();
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reintentar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: _goBack,
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Volver'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Overlay
            AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Builder(
                builder: (context) {
                  final epgAsync = ref.watch(
                    currentProgramProvider(_currentChannel.name),
                  );
                  return _buildOverlay(epgAsync);
                },
              ),
            ),

            // Panel EPG lateral
            if (_showEpgPanel && widget.categoryChannels.isNotEmpty)
              _buildEpgPanel(),
            // Historial overlay
            if (_showHistoryOverlay)
              ChannelHistoryOverlay(
                history: ref.watch(historyProvider),
                epgMap: widget.epgMap,
                currentChannel: _currentChannel,
                currentProgram: _currentEpgProgram,
                onChannelSelected: (channel) {
                  setState(() => _showHistoryOverlay = false);
                  _switchChannel(channel);
                },
                onDismiss: () => setState(() => _showHistoryOverlay = false),
              ),

            // Menú de opciones (long press en botón central)
            if (_showOptionsMenu) _buildOptionsMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(AsyncValue<EpgProgram?> epgAsync) {
    // Capturar programa actual para el historial overlay
    epgAsync.whenData((program) {
      if (_currentEpgProgram != program) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentEpgProgram = program);
        });
      }
    });
    return Stack(
      children: [
        // Gradiente superior
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Info del canal arriba
        Positioned(
          top: 24,
          left: 24,
          right: 24,
          child: Row(
            children: [
              IconButton(
                onPressed: _goBack,
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              if (_currentChannel.streamIcon.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _currentChannel.streamIcon,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.tv, color: Colors.white, size: 48),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentChannel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'En vivo',
                      style: TextStyle(
                        color: Colors.red[400],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '● EN VIVO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Gradiente inferior con EPG
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: epgAsync.when(
              loading: () => _buildHint(),
              error: (e, _) => _buildHint(),
              data: (program) {
                if (program == null) return _buildHint();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AHORA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            program.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          program.timeRange,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (program.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        program.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildHint(small: true),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpgPanel() {
    return Row(
      children: [
        // Panel de canales
        Container(
          width: 320,
          color: Colors.black.withValues(alpha: 0.92),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
                child: const Row(
                  children: [
                    Icon(Icons.tv, color: Colors.deepPurple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CANALES',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Lista de canales
              Expanded(
                child: ListView.builder(
                  controller: _epgChannelScrollController,
                  itemCount: widget.categoryChannels.length,
                  itemBuilder: (context, index) {
                    final channel = widget.categoryChannels[index];
                    final isSelected = index == _epgPanelChannelIndex;
                    final program = _findEpgForChannel(channel.name);

                    return GestureDetector(
                      onTap: () => _switchChannel(channel),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 64,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.deepPurple.withValues(alpha: 0.5)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected
                                  ? Colors.deepPurpleAccent
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Logo
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: channel.streamIcon.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        channel.streamIcon,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.tv,
                                          color: Colors.white38,
                                          size: 18,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.tv,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    channel.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white60,
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (program != null)
                                    Text(
                                      program.title,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.4,
                                        ),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            // Indicador canal actual
                            if (channel.streamId == _currentChannel.streamId)
                              const Icon(
                                Icons.play_arrow,
                                color: Colors.deepPurpleAccent,
                                size: 16,
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
        ),

        // Panel de programación del canal seleccionado
        if (_epgPanelChannelIndex < widget.categoryChannels.length)
          _buildEpgSchedulePanel(
            widget.categoryChannels[_epgPanelChannelIndex],
          ),
      ],
    );
  }

  Widget _buildEpgSchedulePanel(XtreamChannel channel) {
    final programs = ref.watch(channelProgramsProvider(channel.name));

    return Container(
      width: 340,
      color: Colors.black.withValues(alpha: 0.85),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
            child: Text(
              channel.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: programs.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
              error: (e, _) => const Center(
                child: Text(
                  'Sin programación',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              data: (programList) {
                if (programList.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sin programación disponible',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: programList.length,
                  itemBuilder: (context, index) {
                    final program = programList[index];
                    final isNow = program.isNow;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isNow
                            ? Colors.deepPurple.withValues(alpha: 0.3)
                            : Colors.transparent,
                        border: Border(
                          left: BorderSide(
                            color: isNow
                                ? Colors.deepPurpleAccent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              program.timeRange.split('—').first.trim(),
                              style: TextStyle(
                                color: isNow
                                    ? Colors.deepPurpleAccent
                                    : Colors.white38,
                                fontSize: 11,
                                fontWeight: isNow
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  program.title,
                                  style: TextStyle(
                                    color: isNow
                                        ? Colors.white
                                        : Colors.white60,
                                    fontSize: 12,
                                    fontWeight: isNow
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isNow) ...[
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: program.progress,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.deepPurple,
                                          ),
                                      minHeight: 2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  EpgProgram? _findEpgForChannel(String channelName) {
    if (widget.epgMap.isEmpty) return null;
    final normalized = channelName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    for (final entry in widget.epgMap.entries) {
      final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key == normalized ||
          key.contains(normalized) ||
          normalized.contains(key)) {
        return entry.value;
      }
    }
    return null;
  }

  Widget _buildHint({bool small = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, color: Colors.white54, size: small ? 14 : 16),
        const SizedBox(width: 8),
        Text(
          'Presioná OK para mostrar/ocultar · Atrás para salir',
          style: TextStyle(
            color: Colors.white.withValues(alpha: small ? 0.5 : 0.6),
            fontSize: small ? 11 : 12,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MENÚ DE OPCIONES
  // ══════════════════════════════════════════════════════════════

  List<_MenuItem> get _menuItems => [
    _MenuItem(id: 'channels', icon: Icons.list, label: 'Canales'),
    _MenuItem(
      id: 'resolution',
      icon: Icons.high_quality,
      label: _player.state.width != null && _player.state.height != null
          ? '${_player.state.width}×${_player.state.height}'
          : 'Auto',
    ),
    _MenuItem(
      id: 'audio',
      icon: Icons.volume_up,
      label:
          _player.state.track.audio.title ??
          _player.state.track.audio.language ??
          'Audio',
    ),
    _MenuItem(
      id: 'subtitles',
      icon: Icons.closed_caption,
      label: _player.state.track.subtitle.id == 'no'
          ? 'Off'
          : _player.state.track.subtitle.title ??
                _player.state.track.subtitle.language ??
                'On',
    ),
  ];

  bool _handleOptionsMenuKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _selectedMenuIndex = (_selectedMenuIndex - 1).clamp(
          0,
          _menuItems.length - 1,
        );
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _selectedMenuIndex = (_selectedMenuIndex + 1).clamp(
          0,
          _menuItems.length - 1,
        );
      });
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _handleMenuSelection();
    } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _showOptionsMenu = false);
    }
    return true;
  }

  void _handleMenuSelection() {
    final item = _menuItems[_selectedMenuIndex];
    setState(() => _showOptionsMenu = false);

    switch (item.id) {
      case 'channels':
        setState(() => _showEpgPanel = true);
        break;
      case 'audio':
        _showAudioTrackDialog();
        break;
      case 'subtitles':
        _showSubtitleTrackDialog();
        break;
      case 'resolution':
        // Info only - no action
        break;
    }
  }

  Widget _buildOptionsMenu() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF1A1A2E).withValues(alpha: 0.95),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        padding: const EdgeInsets.only(top: 40, bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _menuItems.asMap().entries.map((entry) {
            final isSelected = entry.key == _selectedMenuIndex;
            return _buildMenuItem(entry.value, isSelected);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.deepPurple.withValues(alpha: 0.8)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.deepPurpleAccent, width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _longPressTimer?.cancel();
    _bufferingTimeoutTimer?.cancel();
    _bufferingSubscription?.cancel();
    _errorSubscription?.cancel();
    if (_ownsPlayer && !_isDisposed) {
      _player.dispose();
    }
    _epgChannelScrollController.dispose();
    super.dispose();
  }
}

// Modelo para items del menú de opciones
class _MenuItem {
  final String id;
  final IconData icon;
  final String label;

  const _MenuItem({required this.id, required this.icon, required this.label});
}
