import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared entry point and route tracking for commands invoked above the notes
/// route. Editors register their existing save-and-exit operation here.
class WorkspaceCommands extends NavigatorObserver {
  Future<void> Function()? open;
  bool isOpen = false;
  final routeExits = <Route<dynamic>, Future<void> Function()>{};
  final _routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == null) return;
    final index = _routes.indexOf(oldRoute);
    if (index < 0) return;
    if (newRoute == null) {
      _routes.removeAt(index);
    } else {
      _routes[index] = newRoute;
    }
  }

  Future<bool> reveal(Route<dynamic> target) async {
    if (target.isCurrent) return true;
    if (!_routes.contains(target)) return false;
    while (_routes.isNotEmpty && _routes.last != target) {
      final top = _routes.last;
      final exit = routeExits[top];
      if (exit != null) {
        await exit();
      } else {
        await navigator?.maybePop();
      }
      // A modal or failed editor save can refuse navigation. Leave it intact.
      if (_routes.contains(top)) return false;
    }
    return target.isCurrent;
  }
}

final workspaceCommandsProvider = Provider((ref) => WorkspaceCommands());
