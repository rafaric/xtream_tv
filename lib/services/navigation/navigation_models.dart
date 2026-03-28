/// Result of a navigation operation
class NavigationResult {
  final int newIndex;
  final bool success;
  final NavigationEdge? edge;

  const NavigationResult({
    required this.newIndex,
    required this.success,
    this.edge,
  });
}

/// Edge that was hit during navigation
enum NavigationEdge { left, right, top, bottom }
