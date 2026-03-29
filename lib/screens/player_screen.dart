import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/channel.dart';
import '../providers/xtream_provider.dart';
import '../widgets/channel_history_overlay.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final XtreamChannel channel;
  final String streamUrl;
  final List<XtreamChannel> categoryChannels;
  final Map<String, EpgProgram?> epgMap;

  const PlayerScreen({
    super.key,
    required this.channel,
    required this.streamUrl,
    this.categoryChannels = const [],
    this.epgMap = const {},
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  BetterPlayerController? _controller;
  bool _showOverlay = true;
  bool _isBuffering = true;
  bool _isDisposed = false;
  bool _showEpgPanel = false;
  int _epgPanelChannelIndex = 0;
  late XtreamChannel _currentChannel;
  late String _currentStreamUrl;
  final _epgChannelScrollController = ScrollController();
  bool _showHistoryOverlay = false;

  // Canales para el EPG - puede cambiar si se elige canal de otra categoría
  late List<XtreamChannel> _epgChannels;

  String? _streamError;
  bool _showOptionsMenu = false;
  int _selectedMenuIndex = 0;
  Timer? _longPressTimer;
  bool _isLongPress = false;
  bool _isDialogOpen = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _currentStreamUrl = widget.streamUrl;
    _epgChannels = widget.categoryChannels;

    debugPrint('🎬 PlayerScreen initState');
    debugPrint('🔗 Stream URL: $_currentStreamUrl');

    // Enable wakelock to prevent screensaver during playback
    WakelockPlus.enable();

    _initializePlayer();

    final idx = _epgChannels.indexWhere(
      (c) => c.streamId == _currentChannel.streamId,
    );
    if (idx != -1) _epgPanelChannelIndex = idx;

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOverlay = false);
    });

    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _initializePlayer() {
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      _currentStreamUrl,
      liveStream: true,
      videoFormat: BetterPlayerVideoFormat.other, // Auto-detect format
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 5000,
        maxBufferMs: 30000,
        bufferForPlaybackMs: 2500,
        bufferForPlaybackAfterRebufferMs: 5000,
      ),
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        handleLifecycle: true,
        autoDetectFullscreenAspectRatio: true,
        autoDetectFullscreenDeviceOrientation: false,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
        eventListener: _onPlayerEvent,
      ),
      betterPlayerDataSource: dataSource,
    );

    debugPrint('🎮 BetterPlayerController created');
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;

    debugPrint('📺 BetterPlayer Event: ${event.betterPlayerEventType}');

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.bufferingStart:
        setState(() => _isBuffering = true);
        break;
      case BetterPlayerEventType.bufferingEnd:
        setState(() => _isBuffering = false);
        break;
      case BetterPlayerEventType.play:
        setState(() {
          _isBuffering = false;
          _streamError = null;
        });
        break;
      case BetterPlayerEventType.exception:
        debugPrint('❌ BetterPlayer Exception: ${event.parameters}');
        _handleStreamError();
        break;
      case BetterPlayerEventType.finished:
        debugPrint('⏹️ Stream finished');
        _handleStreamError();
        break;
      default:
        break;
    }
  }

  void _handleStreamError() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      debugPrint('🔄 Auto-retry $_retryCount/$_maxRetries');
      _retryCurrentChannel();
    } else {
      debugPrint('❌ Max retries reached');
      setState(() {
        _streamError = 'Canal no disponible';
        _isBuffering = false;
      });
    }
  }

  Future<void> _retryCurrentChannel() async {
    setState(() {
      _isBuffering = true;
      _streamError = null;
    });
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      _currentStreamUrl,
      liveStream: true,
      videoFormat: BetterPlayerVideoFormat.other,
    );
    await _controller?.setupDataSource(dataSource);
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

    _retryCount = 0;

    // Si el canal es de otra categoría, actualizar la lista del EPG
    final isFromDifferentCategory = !_epgChannels.any(
      (c) => c.streamId == channel.streamId,
    );

    if (isFromDifferentCategory && channel.categoryId.isNotEmpty) {
      // Cargar canales de la nueva categoría
      final newChannels = await ref.read(
        channelsProvider(channel.categoryId).future,
      );
      _epgChannels = newChannels;
      _epgPanelChannelIndex = _epgChannels.indexWhere(
        (c) => c.streamId == channel.streamId,
      );
      if (_epgPanelChannelIndex < 0) _epgPanelChannelIndex = 0;
    }

    setState(() {
      _currentChannel = channel;
      _currentStreamUrl = url;
      _isBuffering = true;
      _streamError = null;
      _showEpgPanel = false;
      _showOverlay = true;
      _showHistoryOverlay = false;
    });

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      liveStream: true,
      videoFormat: BetterPlayerVideoFormat.other,
    );

    await _controller?.setupDataSource(dataSource);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _goBack() {
    if (_isDisposed) return;
    _isDisposed = true;
    // Solo cleanup, el pop lo maneja el sistema
    HardwareKeyboard.instance.removeHandler(_onKey);
    _longPressTimer?.cancel();
    _controller?.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!mounted) return false;
    if (_isDialogOpen) return false;

    final isSelectKey =
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter;

    // Long press detection
    if (isSelectKey &&
        !_showHistoryOverlay &&
        !_showEpgPanel &&
        !_showOptionsMenu) {
      if (event is KeyDownEvent) {
        _isLongPress = false;
        _longPressTimer?.cancel();
        _longPressTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) {
            _isLongPress = true;
            setState(() => _showOptionsMenu = true);
          }
        });
        return true;
      } else if (event is KeyUpEvent) {
        _longPressTimer?.cancel();
        if (!_isLongPress) {
          _toggleOverlay();
        }
        _isLongPress = false;
        return true;
      }
    }

    if (event is! KeyDownEvent) return false;

    // Options menu navigation
    if (_showOptionsMenu) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(
          () => _selectedMenuIndex = (_selectedMenuIndex - 1).clamp(0, 2),
        );
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(
          () => _selectedMenuIndex = (_selectedMenuIndex + 1).clamp(0, 2),
        );
      } else if (isSelectKey) {
        _handleMenuSelect();
      } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _showOptionsMenu = false);
      }
      return true;
    }

    // History overlay - let it handle its own keys
    if (_showHistoryOverlay) {
      return false; // Let ChannelHistoryOverlay handle it
    }

    // EPG panel navigation
    if (_showEpgPanel) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _navigateEpgPanel(-1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _navigateEpgPanel(1);
      } else if (isSelectKey) {
        _selectEpgChannel();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _showEpgPanel = false);
      }
      return true;
    }

    // Main navigation
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _showHistoryOverlay = true);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_epgChannels.isNotEmpty) {
        // Posicionar en el canal actual al abrir el panel EPG
        final currentIdx = _epgChannels.indexWhere(
          (c) => c.streamId == _currentChannel.streamId,
        );
        setState(() {
          _showEpgPanel = true;
          _epgPanelChannelIndex = currentIdx != -1 ? currentIdx : 0;
        });
        // Scroll al canal actual después de que se renderice
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollEpgToIndex(_epgPanelChannelIndex);
        });
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _switchToPreviousChannel();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _switchToNextChannel();
    } else if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      _goBack();
      return false; // No consumir el evento, dejar que se propague
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _toggleOverlay();
    } else {
      return false;
    }
    return true;
  }

  void _handleMenuSelect() {
    setState(() => _showOptionsMenu = false);
    switch (_selectedMenuIndex) {
      case 0:
        _showAudioTrackDialog();
        break;
      case 1:
        _showSubtitleTrackDialog();
        break;
      case 2:
        _showChannelInfo();
        break;
    }
  }

  void _showAudioTrackDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selección de audio no disponible para streams en vivo'),
      ),
    );
  }

  void _showSubtitleTrackDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subtítulos no disponibles para este stream'),
      ),
    );
  }

  void _showChannelInfo() {
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Info del Canal',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nombre: ${_currentChannel.name}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${_currentChannel.streamId}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'URL: $_currentStreamUrl',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ).then((_) => _isDialogOpen = false);
  }

  void _navigateEpgPanel(int direction) {
    final newIndex = _epgPanelChannelIndex + direction;
    if (newIndex >= 0 && newIndex < _epgChannels.length) {
      setState(() => _epgPanelChannelIndex = newIndex);
      _scrollEpgToIndex(newIndex);
    }
  }

  void _scrollEpgToIndex(int index) {
    const itemHeight = 72.0;
    if (_epgChannelScrollController.hasClients) {
      // Centrar el item en la vista (restar mitad de la altura visible)
      final viewportHeight =
          _epgChannelScrollController.position.viewportDimension;
      final targetOffset =
          (index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
      final clampedOffset = targetOffset.clamp(
        0.0,
        _epgChannelScrollController.position.maxScrollExtent,
      );
      _epgChannelScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _selectEpgChannel() {
    if (_epgPanelChannelIndex < _epgChannels.length) {
      _switchChannel(_epgChannels[_epgPanelChannelIndex]);
    }
  }

  void _switchToNextChannel() {
    final idx = _epgChannels.indexWhere(
      (c) => c.streamId == _currentChannel.streamId,
    );
    if (idx >= 0 && idx < _epgChannels.length - 1) {
      _switchChannel(_epgChannels[idx + 1]);
    }
  }

  void _switchToPreviousChannel() {
    final idx = _epgChannels.indexWhere(
      (c) => c.streamId == _currentChannel.streamId,
    );
    if (idx > 0) {
      _switchChannel(_epgChannels[idx - 1]);
    }
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

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          if (_controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: BetterPlayer(controller: _controller!),
              ),
            ),

          // Buffering
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),

          // Error - con debug info
          if (_streamError != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _streamError!,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  // Debug info
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'DEBUG INFO:',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'URL: $_currentStreamUrl',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Canal: ${_currentChannel.name}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          'Retries: $_retryCount/$_maxRetries',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _retryCount = 0;
                      _retryCurrentChannel();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),

          // Overlay
          if (_showOverlay) _buildOverlay(),

          // EPG Panel
          if (_showEpgPanel) _buildEpgPanel(),

          // History overlay
          if (_showHistoryOverlay)
            ChannelHistoryOverlay(
              history: history,
              epgMap: widget.epgMap,
              currentChannel: _currentChannel,
              currentProgram: _findEpgForChannel(_currentChannel.name),
              onChannelSelected: (channel) {
                setState(() => _showHistoryOverlay = false);
                _switchChannel(channel);
              },
              onDismiss: () => setState(() => _showHistoryOverlay = false),
            ),

          // Options menu
          if (_showOptionsMenu) _buildOptionsMenu(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final program = _findEpgForChannel(_currentChannel.name);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(230), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            if (_currentChannel.streamIcon.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  _currentChannel.streamIcon,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.tv, color: Colors.white54, size: 40),
                ),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentChannel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (program != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      program.title,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '● EN VIVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpgPanel() {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 350,
        color: Colors.black.withAlpha(230),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'CANALES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _epgChannelScrollController,
                itemCount: _epgChannels.length,
                itemBuilder: (context, index) {
                  final channel = _epgChannels[index];
                  final isSelected = index == _epgPanelChannelIndex;
                  final isCurrent =
                      channel.streamId == _currentChannel.streamId;
                  final program = _findEpgForChannel(channel.name);

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.deepPurple.withAlpha(150)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? Colors.deepPurpleAccent
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (program != null)
                                Text(
                                  program.title,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(100),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          const Icon(
                            Icons.play_circle_fill,
                            color: Colors.deepPurpleAccent,
                            size: 20,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsMenu() {
    final items = [
      const _MenuItem(
        id: 'audio',
        icon: Icons.audiotrack,
        label: 'Pista de Audio',
      ),
      const _MenuItem(id: 'subs', icon: Icons.subtitles, label: 'Subtítulos'),
      const _MenuItem(
        id: 'info',
        icon: Icons.info_outline,
        label: 'Info del Canal',
      ),
    ];

    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == _selectedMenuIndex;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    item.label,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _longPressTimer?.cancel();
    _controller?.dispose();
    _epgChannelScrollController.dispose();
    // Disable wakelock when leaving player
    WakelockPlus.disable();
    super.dispose();
  }
}

class _MenuItem {
  final String id;
  final IconData icon;
  final String label;
  const _MenuItem({required this.id, required this.icon, required this.label});
}
