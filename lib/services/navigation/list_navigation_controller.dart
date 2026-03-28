import 'navigation_models.dart';

/// Pure Dart controller for 1D list navigation
///
/// Manages sequential navigation within a single-column list layout.
/// Useful for linear content like Live TV channels or Favorites.
///
/// Key behaviors:
/// - UP: Decrements index (move to previous item)
/// - DOWN: Increments index (move to next item)
/// - Boundary detection: Returns [NavigationEdge] when at edges
///
/// Example with 5 items:
/// ```
/// [0] Channel 1
/// [1] Channel 2
/// [2] Channel 3
/// [3] Channel 4
/// [4] Channel 5
/// ```
/// - From index 2, UP → index 1 (previous channel)
/// - From index 2, DOWN → index 3 (next channel)
/// - From index 0, UP → stays at 0 (top edge)
/// - From index 4, DOWN → stays at 4 (bottom edge)
class ListNavigationController {
  final int itemCount;
  int _selectedIndex;

  ListNavigationController({required this.itemCount, int initialIndex = 0})
    : _selectedIndex = initialIndex;

  int get selectedIndex => _selectedIndex;

  /// Navigate up in the list (move to previous item)
  ///
  /// Decrements the selected index by 1, moving to the previous item in the list.
  /// At the top of the list (index 0), returns [NavigationEdge.top]
  /// without changing the index.
  ///
  /// Example:
  /// - From index 2, UP → index 1 (success)
  /// - From index 0, UP → stays at 0 (top edge, returns false)
  NavigationResult navigateUp() {
    if (itemCount == 0 || _selectedIndex <= 0) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.top,
      );
    }

    _selectedIndex--;
    return NavigationResult(newIndex: _selectedIndex, success: true);
  }

  /// Navigate down in the list (move to next item)
  ///
  /// Increments the selected index by 1, moving to the next item in the list.
  /// At the bottom of the list (last item), returns [NavigationEdge.bottom]
  /// without changing the index.
  ///
  /// Example:
  /// - From index 2, DOWN → index 3 (success)
  /// - From index 4 (last item), DOWN → stays at 4 (bottom edge, returns false)
  NavigationResult navigateDown() {
    if (itemCount == 0 || _selectedIndex >= itemCount - 1) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.bottom,
      );
    }

    _selectedIndex++;
    return NavigationResult(newIndex: _selectedIndex, success: true);
  }
}
