/// Navigation constants for grid and list layouts
///
/// This file centralizes all magic numbers used in navigation logic,
/// making it easier to adjust grid dimensions and item heights globally
/// without searching through multiple files.
class NavigationConstants {
  NavigationConstants._(); // Private constructor to prevent instantiation

  /// Number of columns in grid layouts (VOD, Series)
  ///
  /// Used by [GridNavigationController] to calculate row/column positions
  /// and by HomeScreen when rendering grid sections.
  static const int gridColumnsPerRow = 5;

  /// Approximate height of grid items in pixels
  ///
  /// Used for scroll positioning calculations in grid layouts.
  /// Adjust this if grid item height changes in the UI.
  static const double gridItemHeight = 220.0;

  /// Height of list items (Live TV, Favorites) in pixels
  ///
  /// Used for scroll positioning calculations in list layouts.
  /// Adjust this if list item height changes in the UI.
  static const double listItemHeight = 72.0;
}
