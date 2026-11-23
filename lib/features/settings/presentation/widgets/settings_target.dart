import 'package:flutter/material.dart';

/// Links from the command palette reveal the existing control without changing
/// its value or bypassing its confirmation UI.
class SettingsTarget extends StatefulWidget {
  const SettingsTarget({
    super.key,
    required this.title,
    required this.child,
    this.fallbackTitle,
  });
  final String title;
  final String? fallbackTitle;
  final Widget child;

  static Key? keyFor(BuildContext context, String title) {
    final scope = context.dependOnInheritedWidgetOfExactType<_TargetScope>();
    if (scope?.title == title) return scope?.targetKey;
    return scope?.fallbackTitle == title ? scope?.fallbackKey : null;
  }

  @override
  State<SettingsTarget> createState() => _SettingsTargetState();
}

class _SettingsTargetState extends State<SettingsTarget> {
  final _targetKey = GlobalKey();
  final _fallbackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _targetKey.currentContext ?? _fallbackKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.2);
    });
  }

  @override
  Widget build(BuildContext context) => _TargetScope(
    title: widget.title,
    fallbackTitle: widget.fallbackTitle,
    fallbackKey: _fallbackKey,
    targetKey: _targetKey,
    child: widget.child,
  );
}

class _TargetScope extends InheritedWidget {
  const _TargetScope({
    required this.title,
    required this.targetKey,
    required this.fallbackTitle,
    required this.fallbackKey,
    required super.child,
  });
  final String title;
  final GlobalKey targetKey;
  final String? fallbackTitle;
  final GlobalKey fallbackKey;
  @override
  bool updateShouldNotify(_TargetScope oldWidget) => title != oldWidget.title;
}

/// Settings pages have small, bounded control lists. Mount their controls so a
/// deep link can reveal a control below the viewport on the first frame.
class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.padding,
    required this.children,
  });
  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
