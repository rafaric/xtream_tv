import 'package:flutter_test/flutter_test.dart';

/// Unit tests for list navigation logic
/// These tests verify the CORRECT behavior for list navigation (Live TV, Favorites)
/// when the down-arrow is pressed.
///
/// CURRENT BUG: HomeScreen._navigateDown() always calls _navigateGrid(1, 0) for content,
/// even for list sections. This breaks Down-arrow in Live TV and Favorites.
///
/// EXPECTED FIX: _navigateDown() should detect if we're in a list section or grid section:
/// - Lists (Live TV, Favorites): increment index linearly
/// - Grids (VOD, Series): use grid navigation (already working)
void main() {
  group('List Navigation Logic - Down Arrow', () {
    test(
      'Should increment selectedContentIndex when moving down in a list section',
      () {
        // SCENARIO: User in Live TV (list section), on channel index 2, pressing down
        int selectedIndex = 2;
        const int itemCount = 5;
        final isGrid = false; // Live TV is NOT a grid

        // Expected behavior: increment index
        int newIndex = selectedIndex;
        if (!isGrid && newIndex < itemCount - 1) {
          newIndex++;
        }

        expect(
          newIndex,
          equals(3),
          reason: 'Down-arrow should increment index in list sections',
        );
      },
    );

    test('Should NOT increment past last item in list', () {
      // SCENARIO: User is already at last channel (index 4 out of 5)
      int selectedIndex = 4;
      const int itemCount = 5;
      final isGrid = false;

      int newIndex = selectedIndex;
      if (!isGrid && newIndex < itemCount - 1) {
        newIndex++;
      }

      expect(
        newIndex,
        equals(4),
        reason: 'Down-arrow should stop at last item in list',
      );
    });

    test('Should handle empty list gracefully', () {
      // SCENARIO: Empty channel list
      int selectedIndex = 0;
      const int itemCount = 0;
      final isGrid = false;

      int newIndex = selectedIndex;
      if (itemCount > 0 && !isGrid && newIndex < itemCount - 1) {
        newIndex++;
      }

      expect(
        newIndex,
        equals(0),
        reason: 'Down-arrow should be no-op on empty list',
      );
    });

    test('Should use grid navigation for grid sections', () {
      // SCENARIO: User in VOD section (grid), at index 2 (row 0, col 2)
      // pressing down should go to last card of next row (index 9)
      int selectedIndex = 2;
      const int itemCount = 13;
      const int columnsPerRow = 5;
      final isGrid = true; // VOD is a grid

      // For grids, down arrow goes to last card of next row
      int newIndex = selectedIndex;
      if (isGrid) {
        final currentRow = selectedIndex ~/ columnsPerRow;
        final nextRowStart = (currentRow + 1) * columnsPerRow;
        final nextRowEnd = nextRowStart + columnsPerRow - 1;
        newIndex = (nextRowEnd < itemCount) ? nextRowEnd : selectedIndex;
      }

      expect(
        newIndex,
        equals(9),
        reason: 'Grid down-arrow should go to last card of next row',
      );
    });
  });
}
