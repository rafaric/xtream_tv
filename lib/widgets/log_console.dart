import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class LogEntry {
  final Level level;
  final String message;
  final DateTime timestamp;

  LogEntry(this.level, this.message, this.timestamp);
}

class InAppLogger extends LogOutput {
  static final List<LogEntry> _logs = [];
  static final ValueNotifier<List<LogEntry>> logNotifier = ValueNotifier(_logs);

  @override
  void output(OutputEvent event) {
    // Solo mostramos un mensaje por evento de log
    final message = event.lines.join('\n');
    final entry = LogEntry(event.level, message, DateTime.now());

    _logs.add(entry);
    if (_logs.length > 100) {
      // Mantener solo los últimos 100 logs
      _logs.removeAt(0);
    }
    logNotifier.value = List.from(_logs);
  }
}

class LogConsoleOverlay extends StatefulWidget {
  final Widget child;

  const LogConsoleOverlay({super.key, required this.child});

  @override
  State<LogConsoleOverlay> createState() => _LogConsoleOverlayState();
}

class _LogConsoleOverlayState extends State<LogConsoleOverlay> {
  bool _showLogs = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [widget.child, if (_showLogs) _buildLogConsole()]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _showLogs = !_showLogs),
        backgroundColor: Colors.deepPurple.withAlpha(150),
        child: Icon(_showLogs ? Icons.close : Icons.bug_report),
      ),
    );
  }

  Widget _buildLogConsole() {
    return Positioned(
      bottom: 80,
      left: 10,
      right: 10,
      height: 250,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: ValueListenableBuilder<List<LogEntry>>(
          valueListenable: InAppLogger.logNotifier,
          builder: (context, logs, child) {
            return ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Text(
                  '[${log.level.name.toUpperCase()}] ${log.timestamp.toIso8601String().substring(11, 23)}: ${log.message}',
                  style: TextStyle(
                    color: _getColorForLevel(log.level),
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getColorForLevel(Level level) {
    switch (level) {
      case Level.error:
        return Colors.red;
      case Level.warning:
        return Colors.orange;
      case Level.info:
        return Colors.cyan;
      default:
        return Colors.white;
    }
  }
}
