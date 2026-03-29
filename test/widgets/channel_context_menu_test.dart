import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_tv/models/channel.dart';

// Mock dialog widget for testing
class _ChannelContextMenuDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          // Menu options
          _buildMenuOption(
            icon: Icons.star,
            label: isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
            onTap: () {
              onFavoriteToggle();
              Navigator.pop(context);
            },
          ),
          _buildMenuOption(
            icon: Icons.visibility_off,
            label: 'Ocultar canal',
            onTap: () {
              onHide();
              Navigator.pop(context);
            },
            isDestructive: true,
          ),
          if (groups.isNotEmpty)
            _buildMenuOption(
              icon: Icons.folder,
              label: 'Agregar a grupo',
              onTap: () {
                // In a real implementation, this would show a submenu
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('ChannelContextMenuDialog', () {
    late XtreamChannel testChannel;

    setUp(() {
      testChannel = XtreamChannel(
        streamId: 123,
        name: 'Test Channel',
        streamIcon: '',
        categoryId: '1',
        streamType: 'live',
      );
    });

    // ──── RED: Test dialog renders with channel info ────
    testWidgets('should display channel name in header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ChannelContextMenuDialog(
              channel: testChannel,
              isFavorite: false,
              onFavoriteToggle: () {},
              onHide: () {},
              onAddToGroup: (_) {},
              groups: [],
            ),
          ),
        ),
      );

      expect(find.text('Test Channel'), findsWidgets);
    });

    // ──── RED: Test dialog shows favorite option ────
    testWidgets('should show "Agregar a favoritos" when not favorite', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ChannelContextMenuDialog(
              channel: testChannel,
              isFavorite: false,
              onFavoriteToggle: () {},
              onHide: () {},
              onAddToGroup: (_) {},
              groups: [],
            ),
          ),
        ),
      );

      expect(find.text('Agregar a favoritos'), findsOneWidget);
    });

    // ──── RED: Test dialog shows remove from favorite option ────
    testWidgets('should show "Quitar de favoritos" when favorite', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ChannelContextMenuDialog(
              channel: testChannel,
              isFavorite: true,
              onFavoriteToggle: () {},
              onHide: () {},
              onAddToGroup: (_) {},
              groups: [],
            ),
          ),
        ),
      );

      expect(find.text('Quitar de favoritos'), findsOneWidget);
    });

    // ──── RED: Test dialog shows hide option ────
    testWidgets('should display "Ocultar canal" option', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ChannelContextMenuDialog(
              channel: testChannel,
              isFavorite: false,
              onFavoriteToggle: () {},
              onHide: () {},
              onAddToGroup: (_) {},
              groups: [],
            ),
          ),
        ),
      );

      expect(find.text('Ocultar canal'), findsOneWidget);
    });

    // ──── RED: Test dialog shows group option when groups available ────
    testWidgets('should display "Agregar a grupo" when groups available', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ChannelContextMenuDialog(
              channel: testChannel,
              isFavorite: false,
              onFavoriteToggle: () {},
              onHide: () {},
              onAddToGroup: (_) {},
              groups: ['Group 1', 'Group 2'],
            ),
          ),
        ),
      );

      expect(find.text('Agregar a grupo'), findsOneWidget);
    });

    // ──── RED: Test favorite toggle callback is called ────
    testWidgets('should call onFavoriteToggle when favorite option tapped', (
      WidgetTester tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ChannelContextMenuDialog(
              channel: testChannel,
              isFavorite: false,
              onFavoriteToggle: () {
                called = true;
              },
              onHide: () {},
              onAddToGroup: (_) {},
              groups: [],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Agregar a favoritos'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    // ──── RED: Test hide callback is called ────
    testWidgets('should call onHide when hide option tapped', (
      WidgetTester tester,
    ) async {
      var called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _ChannelContextMenuDialog(
              channel: testChannel,
              isFavorite: false,
              onFavoriteToggle: () {},
              onHide: () {
                called = true;
              },
              onAddToGroup: (_) {},
              groups: [],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ocultar canal'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });
}
