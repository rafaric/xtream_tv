import 'navigation_models.dart';

/// Pure Dart controller for 1D list navigation
class ListNavigationController {
  final int itemCount;
  int _selectedIndex;

  ListNavigationController({required this.itemCount, int initialIndex = 0})
    : _selectedIndex = initialIndex;

  int get selectedIndex => _selectedIndex;

  /// Navigate up in the list (decrement index)
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

  /// Navigate down in the list (increment index)
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
