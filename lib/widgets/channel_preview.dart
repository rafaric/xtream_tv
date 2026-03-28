import 'package:flutter/material.dart';
import '../models/channel.dart';

/// Widget de preview de canal - temporalmente deshabilitado durante migración
/// TODO: Reimplementar con BetterPlayer
class ChannelPreview extends StatelessWidget {
  final XtreamChannel channel;
  final EpgProgram? currentProgram;

  const ChannelPreview({super.key, required this.channel, this.currentProgram});

  @override
  Widget build(BuildContext context) {
    // Placeholder mientras se implementa con BetterPlayer
    return Container(
      height: 200,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tv, color: Colors.deepPurple, size: 48),
            const SizedBox(height: 8),
            Text(
              channel.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (currentProgram != null) ...[
              const SizedBox(height: 4),
              Text(
                currentProgram!.title,
                style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
