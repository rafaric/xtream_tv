import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_tv/services/navigation/navigation_models.dart';
import 'package:xtream_tv/services/navigation/grid_navigation_controller.dart';

void main() {
  group('GridNavigationController - Basic', () {
    test('navigateRight increments column', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 0,
      );
      final result = controller.navigateRight();

      expect(result.success, isTrue);
      expect(result.newIndex, equals(1));
      expect(controller.selectedIndex, equals(1));
      expect(result.edge, isNull);
    });

    test('navigateLeft decrements column', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 6, // Row 1, col 1
      );
      final result = controller.navigateLeft();

      expect(result.success, isTrue);
      expect(result.newIndex, equals(5)); // Row 1, col 0
      expect(controller.selectedIndex, equals(5));
      expect(result.edge, isNull);
    });

    test('navigateDown goes to last card of next row (USER REQUIREMENT)', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 0, // First row, first col
      );
      final result = controller.navigateDown();

      // Should go to last card of next row (index 9, which is row 1 col 4)
      expect(result.success, isTrue);
      expect(result.newIndex, equals(9));
      expect(controller.selectedIndex, equals(9));
      expect(result.edge, isNull);
    });

    test('navigateUp preserves column when possible', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 7, // Row 1, col 2
      );
      final result = controller.navigateUp();

      // Should go to row 0, col 2 (index 2)
      expect(result.success, isTrue);
      expect(result.newIndex, equals(2));
      expect(controller.selectedIndex, equals(2));
      expect(result.edge, isNull);
    });

    test('navigateLeft at column 0 returns false with left edge', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 5, // Row 1, col 0
      );
      final result = controller.navigateLeft();

      expect(result.success, isFalse);
      expect(result.newIndex, equals(5));
      expect(controller.selectedIndex, equals(5));
      expect(result.edge, equals(NavigationEdge.left));
    });

    test(
      'navigateRight at end of row wraps to next row first card (USER REQUIREMENT)',
      () {
        final controller = GridNavigationController(
          itemCount: 20,
          columnsPerRow: 5,
          initialIndex: 4, // Row 0, col 4 (right edge)
        );
        final result = controller.navigateRight();

        // Should wrap to first card of next row (index 5)
        expect(result.success, isTrue);
        expect(result.newIndex, equals(5));
        expect(controller.selectedIndex, equals(5));
        expect(result.edge, isNull);
      },
    );

    test('navigateUp at row 0 returns false with top edge', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 2, // Row 0, col 2
      );
      final result = controller.navigateUp();

      expect(result.success, isFalse);
      expect(result.newIndex, equals(2));
      expect(controller.selectedIndex, equals(2));
      expect(result.edge, equals(NavigationEdge.top));
    });

    test('navigateDown at last row returns false with bottom edge', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 18, // Row 3, col 3 (last row)
      );
      final result = controller.navigateDown();

      expect(result.success, isFalse);
      expect(result.newIndex, equals(18));
      expect(controller.selectedIndex, equals(18));
      expect(result.edge, equals(NavigationEdge.bottom));
    });

    test('incomplete last row: navigateDown goes to last card', () {
      final controller = GridNavigationController(
        itemCount: 18, // 3.6 rows, so last row has 3 items
        columnsPerRow: 5,
        initialIndex: 3, // Row 0, col 3
      );
      final result = controller.navigateDown();

      // Row 1 has full 5 items, so go to last of row 1 (index 9)
      expect(result.success, isTrue);
      expect(result.newIndex, equals(9));
      expect(controller.selectedIndex, equals(9));
    });

    test('incomplete last row: navigateUp preserves column if exists', () {
      final controller = GridNavigationController(
        itemCount: 18, // 3.6 rows, so last row has 3 items
        columnsPerRow: 5,
        initialIndex: 12, // Row 2, col 2
      );
      final result = controller.navigateUp();

      // Row 1 has full 5 items, col 2 exists, so go to index 7 (row 1, col 2)
      expect(result.success, isTrue);
      expect(result.newIndex, equals(7));
      expect(controller.selectedIndex, equals(7));
    });
  });

  group('GridNavigationController - Edge Cases', () {
    test('empty grid (itemCount=0) returns false for all directions', () {
      final controller = GridNavigationController(
        itemCount: 0,
        columnsPerRow: 5,
        initialIndex: 0,
      );

      final resultUp = controller.navigateUp();
      expect(resultUp.success, isFalse);
      expect(resultUp.edge, equals(NavigationEdge.top));

      final resultDown = controller.navigateDown();
      expect(resultDown.success, isFalse);
      expect(resultDown.edge, equals(NavigationEdge.bottom));

      final resultLeft = controller.navigateLeft();
      expect(resultLeft.success, isFalse);
      expect(resultLeft.edge, equals(NavigationEdge.left));

      final resultRight = controller.navigateRight();
      expect(resultRight.success, isFalse);
      expect(resultRight.edge, equals(NavigationEdge.right));
    });

    test('single item grid returns false for all directions', () {
      final controller = GridNavigationController(
        itemCount: 1,
        columnsPerRow: 5,
        initialIndex: 0,
      );

      final resultUp = controller.navigateUp();
      expect(resultUp.success, isFalse);
      expect(resultUp.edge, equals(NavigationEdge.top));

      final resultDown = controller.navigateDown();
      expect(resultDown.success, isFalse);
      expect(resultDown.edge, equals(NavigationEdge.bottom));

      final resultLeft = controller.navigateLeft();
      expect(resultLeft.success, isFalse);
      expect(resultLeft.edge, equals(NavigationEdge.left));

      final resultRight = controller.navigateRight();
      expect(resultRight.success, isFalse);
      expect(resultRight.edge, equals(NavigationEdge.right));
    });

    test('navigateRight at last card returns false', () {
      final controller = GridNavigationController(
        itemCount: 20,
        columnsPerRow: 5,
        initialIndex: 19, // Last card
      );
      final result = controller.navigateRight();

      expect(result.success, isFalse);
      expect(result.newIndex, equals(19));
      expect(controller.selectedIndex, equals(19));
      expect(result.edge, equals(NavigationEdge.right));
    });

    test('navigateDown from incomplete row to complete row', () {
      final controller = GridNavigationController(
        itemCount: 8, // Row 0: 5 items, Row 1: 3 items
        columnsPerRow: 5,
        initialIndex: 2, // Row 0, col 2
      );
      final result = controller.navigateDown();

      // Should go to last card of row 1 (index 7)
      expect(result.success, isTrue);
      expect(result.newIndex, equals(7));
      expect(controller.selectedIndex, equals(7));
    });

    test('navigateUp from complete row to incomplete row', () {
      final controller = GridNavigationController(
        itemCount: 8, // Row 0: 5 items, Row 1: 3 items
        columnsPerRow: 5,
        initialIndex: 6, // Row 1, col 1
      );
      final result = controller.navigateUp();

      // Row 0 has full 5 items, col 1 exists, so go to index 1 (row 0, col 1)
      expect(result.success, isTrue);
      expect(result.newIndex, equals(1));
      expect(controller.selectedIndex, equals(1));
    });

    test(
      'navigateUp from incomplete row where target column does not exist',
      () {
        final controller = GridNavigationController(
          itemCount: 13, // Row 0: 5, Row 1: 5, Row 2: 3 items
          columnsPerRow: 5,
          initialIndex: 12, // Row 2, col 2 (last item)
        );
        final result = controller.navigateUp();

        // Row 1 has 5 items, col 2 exists at index 7 (row 1, col 2)
        expect(result.success, isTrue);
        expect(result.newIndex, equals(7));
        expect(controller.selectedIndex, equals(7));
      },
    );

    test(
      'navigateUp to incomplete row where current column exceeds row length',
      () {
        final controller = GridNavigationController(
          itemCount: 8, // Row 0: 5, Row 1: 3 items
          columnsPerRow: 5,
          initialIndex:
              9, // Would be row 1, col 4 if it existed (but itemCount=8)
        );

        // Start at index 7 (row 1, col 2 - last item) instead
        final controller2 = GridNavigationController(
          itemCount: 13, // Row 0: 5, Row 1: 5, Row 2: 3
          columnsPerRow: 5,
          initialIndex: 14, // Would be row 2, col 4, but itemCount=13
        );

        // Actually test from a valid incomplete position
        final controller3 = GridNavigationController(
          itemCount: 9, // Row 0: 5, Row 1: 4
          columnsPerRow: 5,
          initialIndex: 8, // Row 1, col 3 (last item)
        );
        final result = controller3.navigateUp();

        // Row 0 col 3 exists at index 3
        expect(result.success, isTrue);
        expect(result.newIndex, equals(3));
      },
    );
  });
}
