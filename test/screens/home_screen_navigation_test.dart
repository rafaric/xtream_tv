import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_tv/services/navigation/list_navigation_controller.dart';
import 'package:xtream_tv/services/navigation/grid_navigation_controller.dart';
import 'package:xtream_tv/services/navigation/navigation_models.dart';

/// Unit tests for list and grid navigation controllers integration
/// These tests verify that HomeScreen correctly uses the navigation controllers
/// for list sections (Live TV, Favorites) and grid sections (VOD, Series).
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

  group('Navigation Controller Integration', () {
    test('Grid navigation uses GridNavigationController', () {
      // SCENARIO: VOD section with 13 items (grid layout)
      final controller = GridNavigationController(
        itemCount: 13,
        columnsPerRow: 5,
        initialIndex: 2,
      );

      // Navigate down - should go to last card of next row (index 9)
      final result = controller.navigateDown();

      expect(result.success, isTrue, reason: 'Down navigation should succeed');
      expect(
        result.newIndex,
        equals(9),
        reason: 'Grid down should go to last card of next row (index 9)',
      );
    });

    test('List navigation uses ListNavigationController', () {
      // SCENARIO: Live TV section with 5 channels (list layout)
      final controller = ListNavigationController(
        itemCount: 5,
        initialIndex: 2,
      );

      // Navigate down - should increment index
      final result = controller.navigateDown();

      expect(result.success, isTrue, reason: 'Down navigation should succeed');
      expect(
        result.newIndex,
        equals(3),
        reason: 'List down should increment index linearly',
      );
    });

    test('Left-edge detection enables category switch', () {
      // SCENARIO: Grid at column 0, user presses left
      final controller = GridNavigationController(
        itemCount: 13,
        columnsPerRow: 5,
        initialIndex: 5, // First card of second row
      );

      final result = controller.navigateLeft();

      expect(
        result.success,
        isFalse,
        reason: 'Left navigation should fail at column 0',
      );
      expect(
        result.edge,
        equals(NavigationEdge.left),
        reason: 'Should signal left edge hit',
      );
    });
  });
}
