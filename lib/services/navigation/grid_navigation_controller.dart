import 'dart:math';

import 'navigation_models.dart';

/// Pure Dart controller for 2D grid navigation
///
/// Manages navigation within a grid layout with wrapping behavior.
/// Grid is conceptually organized in rows where each row has [columnsPerRow] columns.
///
/// Key behaviors:
/// - DOWN: Moves to the LAST card of the next row (user requirement)
/// - RIGHT at row edge: Wraps to FIRST card of the next row
/// - UP: Preserves column position, or goes to last card if column doesn't exist
/// - LEFT at column 0: Returns false (boundary detected)
///
/// Example with 5 columns and 6 items:
/// ```
/// Row 0: [0] [1] [2] [3] [4]
/// Row 1: [5]
/// ```
/// - From index 2, DOWN → index 5 (last card of row below)
/// - From index 4, RIGHT → index 5 (wraps to next row, first card)
/// - From index 5, UP → tries column 2, gets it (index 2)
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

  /// Navigate left (decrement column position)
  ///
  /// Moves one column to the left within the same row.
  /// At the leftmost column (column 0), returns [NavigationEdge.left]
  /// without changing the index.
  ///
  /// Example (5-column grid):
  /// - From index 3 → index 2 (success)
  /// - From index 2 (column 0) → stays at 2 (edge detected, returns false)
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

  /// Navigate right (increment column position, with wrap to next row)
  ///
  /// Moves one column to the right within the same row.
  /// At the rightmost column of a row, wraps to the FIRST card of the next row.
  /// At the last item in the grid, returns [NavigationEdge.right] without changing index.
  ///
  /// Example (5-column grid, 8 items):
  /// - From index 2 → index 3 (success)
  /// - From index 4 (last col of row 0) → index 5 (first card of row 1)
  /// - From index 7 (last item) → stays at 7 (edge detected, returns false)
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

  /// Navigate up (move to the row above, preserving column position)
  ///
  /// Moves to the same column position in the row above.
  /// If the target column doesn't exist (e.g., last row is incomplete),
  /// goes to the last card available in the target row.
  ///
  /// At the top row (row 0), returns [NavigationEdge.top] without changing index.
  ///
  /// Example (5-column grid, 8 items):
  /// ```
  /// Row 0: [0] [1] [2] [3] [4]
  /// Row 1: [5] [6] [7]        ← row is incomplete
  /// ```
  /// - From index 7 (column 2), UP → goes to index 2 (column 2 exists)
  /// - From index 6 (column 1), UP → goes to index 1 (column 1 exists)
  /// - From index 0 (top row), UP → stays at 0 (edge detected, returns false)
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

  /// Navigate down (move to the row below, landing on the LAST card)
  ///
  /// **User Requirement**: Down arrow always goes to the LAST card of the next row,
  /// NOT the same column. This differs from traditional grid navigation.
  ///
  /// At the last row, returns [NavigationEdge.bottom] without changing index.
  ///
  /// Example (5-column grid, 8 items):
  /// ```
  /// Row 0: [0] [1] [2] [3] [4]
  /// Row 1: [5] [6] [7]        ← last row is incomplete
  /// ```
  /// - From index 1 (anywhere in row 0), DOWN → index 7 (last card of row 1)
  /// - From index 7 (bottom row), DOWN → stays at 7 (edge detected, returns false)
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
