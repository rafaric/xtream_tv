import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';

class ChannelHistoryOverlay extends StatefulWidget {
  final List<XtreamChannel> history;
  final Map<String, EpgProgram?> epgMap;
  final XtreamChannel currentChannel;
  final EpgProgram? currentProgram;
  final Function(XtreamChannel) onChannelSelected;
  final VoidCallback onDismiss;

  const ChannelHistoryOverlay({
    super.key,
    required this.history,
    required this.epgMap,
    required this.currentChannel,
    required this.currentProgram,
    required this.onChannelSelected,
    required this.onDismiss,
  });

  @override
  State<ChannelHistoryOverlay> createState() => _ChannelHistoryOverlayState();
}

class _ChannelHistoryOverlayState extends State<ChannelHistoryOverlay> {
  int _selectedIndex = 0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _scrollController.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;

    final history = widget.history
        .where((c) => c.streamId != widget.currentChannel.streamId)
        .toList();

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_selectedIndex < history.length - 1) {
        setState(() => _selectedIndex++);
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (history.isNotEmpty && _selectedIndex < history.length) {
        widget.onChannelSelected(history[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
    } else {
      return false;
    }
    return true;
  }

  void _scrollToSelected() {
    const itemWidth = 180.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _selectedIndex * itemWidth,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  EpgProgram? _findEpg(String channelName) {
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
    final history = widget.history
        .where((c) => c.streamId != widget.currentChannel.streamId)
        .toList();

    return Container(
        color: Colors.transparent,
        child: Column(
          children: [
            // Spacer para empujar contenido abajo
            const Spacer(),

            // Info del canal actual
            _buildCurrentChannelInfo(),

            // Carrusel de historial
            if (history.isNotEmpty) _buildHistoryCarousel(history),

            const SizedBox(height: 16),
          ],
        ),
    );
  }

  Widget _buildCurrentChannelInfo() {
    final program = widget.currentProgram;
    //final nextProgram = null; TODO: próximo programa

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.95), Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Logo + info
              if (widget.currentChannel.streamIcon.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.currentChannel.streamIcon,
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.tv, color: Colors.white54, size: 48),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (program != null) ...[
                      Text(
                        program.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            program.timeRange,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${program.durationMinutes} min',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.currentChannel.name,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        widget.currentChannel.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Barra de progreso
          if (program != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: program.progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Colors.deepPurple,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCarousel(List<XtreamChannel> history) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final channel = history[index];
            final isSelected = index == _selectedIndex;
            final program = _findEpg(channel.name);

            return GestureDetector(
              onTap: () => widget.onChannelSelected(channel),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 168,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurple.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.deepPurpleAccent
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    // Logo
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: channel.streamIcon.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                channel.streamIcon,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.tv,
                                  color: Colors.white38,
                                  size: 22,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.tv,
                              color: Colors.white38,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 8),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            channel.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (program != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              program.title,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: program.progress,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
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
              ),
            );
          },
        ),
      ),
    );
  }
}
