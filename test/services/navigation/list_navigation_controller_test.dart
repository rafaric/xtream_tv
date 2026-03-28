import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_tv/services/navigation/navigation_models.dart';
import 'package:xtream_tv/services/navigation/list_navigation_controller.dart';

void main() {
  group('ListNavigationController', () {
    test('navigateDown increments index', () {
      final controller = ListNavigationController(
        itemCount: 5,
        initialIndex: 0,
      );
      final result = controller.navigateDown();

      expect(result.success, isTrue);
      expect(result.newIndex, equals(1));
      expect(controller.selectedIndex, equals(1));
      expect(result.edge, isNull);
    });

    test('navigateUp decrements index', () {
      final controller = ListNavigationController(
        itemCount: 5,
        initialIndex: 2,
      );
      final result = controller.navigateUp();

      expect(result.success, isTrue);
      expect(result.newIndex, equals(1));
      expect(controller.selectedIndex, equals(1));
      expect(result.edge, isNull);
    });

    test('navigateUp at index 0 returns false', () {
      final controller = ListNavigationController(
        itemCount: 5,
        initialIndex: 0,
      );
      final result = controller.navigateUp();

      expect(result.success, isFalse);
      expect(result.newIndex, equals(0));
      expect(controller.selectedIndex, equals(0));
      expect(result.edge, equals(NavigationEdge.top));
    });

    test('navigateDown at last index returns false', () {
      final controller = ListNavigationController(
        itemCount: 5,
        initialIndex: 4,
      );
      final result = controller.navigateDown();

      expect(result.success, isFalse);
      expect(result.newIndex, equals(4));
      expect(controller.selectedIndex, equals(4));
      expect(result.edge, equals(NavigationEdge.bottom));
    });

    test('empty list (itemCount=0) returns false for all directions', () {
      final controller = ListNavigationController(
        itemCount: 0,
        initialIndex: 0,
      );

      final resultDown = controller.navigateDown();
      expect(resultDown.success, isFalse);
      expect(resultDown.edge, equals(NavigationEdge.bottom));

      final resultUp = controller.navigateUp();
      expect(resultUp.success, isFalse);
      expect(resultUp.edge, equals(NavigationEdge.top));
    });
  });
}
