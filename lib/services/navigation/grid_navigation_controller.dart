import 'dart:math';

import 'navigation_models.dart';

/// Pure Dart controller for 2D grid navigation
class GridNavigationController {
  final int itemCount;
  final int columnsPerRow;
  int _selectedIndex;

  GridNavigationController({
    required this.itemCount,
    required this.columnsPerRow,
    int initialIndex = 0,
  }) : _selectedIndex = initialIndex;

  int get selectedIndex => _selectedIndex;

  /// Navigate left (decrement column)
  NavigationResult navigateLeft() {
    if (itemCount == 0) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.left,
      );
    }

    final currentCol = _selectedIndex % columnsPerRow;
    if (currentCol == 0) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.left,
      );
    }

    _selectedIndex--;
    return NavigationResult(newIndex: _selectedIndex, success: true);
  }

  /// Navigate right (increment column)
  /// At end of row: wrap to first card of next row
  NavigationResult navigateRight() {
    if (itemCount == 0) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.right,
      );
    }

    final currentCol = _selectedIndex % columnsPerRow;

    // At right edge of row: wrap to next row first card
    if (currentCol == columnsPerRow - 1) {
      final currentRow = _selectedIndex ~/ columnsPerRow;
      final nextRowFirstCard = (currentRow + 1) * columnsPerRow;

      if (nextRowFirstCard >= itemCount) {
        // No next row exists
        return NavigationResult(
          newIndex: _selectedIndex,
          success: false,
          edge: NavigationEdge.right,
        );
      }

      _selectedIndex = nextRowFirstCard;
      return NavigationResult(newIndex: _selectedIndex, success: true);
    }

    // Normal case: move right within row
    if (_selectedIndex + 1 >= itemCount) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.right,
      );
    }

    _selectedIndex++;
    return NavigationResult(newIndex: _selectedIndex, success: true);
  }

  /// Navigate up (go to same column in row above)
  /// If column doesn't exist in target row, go to last card of that row
  NavigationResult navigateUp() {
    if (itemCount == 0) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.top,
      );
    }

    final currentRow = _selectedIndex ~/ columnsPerRow;

    if (currentRow == 0) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.top,
      );
    }

    final currentCol = _selectedIndex % columnsPerRow;
    final targetRow = currentRow - 1;
    final targetIndex = targetRow * columnsPerRow + currentCol;

    // Check if target index exists
    if (targetIndex < itemCount) {
      // Card exists at same column in target row
      _selectedIndex = targetIndex;
      return NavigationResult(newIndex: _selectedIndex, success: true);
    }

    // Card doesn't exist: go to last card of target row
    final targetRowLastCard = min(
      (targetRow + 1) * columnsPerRow - 1,
      itemCount - 1,
    );

    _selectedIndex = targetRowLastCard;
    return NavigationResult(newIndex: _selectedIndex, success: true);
  }

  /// Navigate down (go to last card of row below)
  /// User requirement: Down arrow → go to last card of the row below
  NavigationResult navigateDown() {
    if (itemCount == 0) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.bottom,
      );
    }

    if (_selectedIndex >= itemCount - 1) {
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.bottom,
      );
    }

    final currentRow = _selectedIndex ~/ columnsPerRow;
    final targetRow = currentRow + 1;

    // Calculate last card in target row
    final targetRowFirstCard = targetRow * columnsPerRow;
    if (targetRowFirstCard >= itemCount) {
      // No next row exists
      return NavigationResult(
        newIndex: _selectedIndex,
        success: false,
        edge: NavigationEdge.bottom,
      );
    }

    final targetRowLastCard = min(
      (targetRow + 1) * columnsPerRow - 1,
      itemCount - 1,
    );

    _selectedIndex = targetRowLastCard;

    return NavigationResult(newIndex: _selectedIndex, success: true);
  }
}
