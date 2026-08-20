import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// An Inset Grouped card container following the iOS / Bear Notes design language.
class FormCard extends StatelessWidget {
  const FormCard({
    super.key,
    required this.children,
    this.margin,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// An ultra-thin 1px inset divider line aligning with the text start column.
class FormDivider extends StatelessWidget {
  const FormDivider({
    super.key,
    this.indent = 52.0,
    this.endIndent = 0.0,
  });

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Divider(
      color: colors.divider.withValues(alpha: 0.5),
      height: 1,
      thickness: 1.0,
      indent: indent,
      endIndent: endIndent,
    );
  }
}

/// An iOS flush list row for text input inside a [FormCard].
class FormInputRow extends StatefulWidget {
  const FormInputRow({
    super.key,
    required this.controller,
    this.icon,
    this.labelText,
    this.hintText,
    this.helperText,
    this.obscureText = false,
    this.keyboardType,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final IconData? icon;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  State<FormInputRow> createState() => _FormInputRowState();
}

class _FormInputRowState extends State<FormInputRow> {
  late FocusNode _focusNode;
  bool _internalFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    }
    _isFocused = _focusNode.hasFocus;
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant FormInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_internalFocusNode) {
        _focusNode.removeListener(_handleFocusChange);
        _focusNode.dispose();
        _internalFocusNode = false;
      } else {
        oldWidget.focusNode?.removeListener(_handleFocusChange);
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
      } else {
        _focusNode = FocusNode();
        _internalFocusNode = true;
      }
      _isFocused = _focusNode.hasFocus;
      _focusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: _isFocused ? colors.accent : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12.0),
          ],
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontSize: 15.0,
              ),
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                helperText: widget.helperText,
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                labelStyle: AppTypography.bodySmall.copyWith(
                  color: _isFocused ? colors.accent : colors.textSecondary,
                  fontSize: 14.0,
                ),
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: colors.textTertiary,
                  fontSize: 15.0,
                ),
                helperStyle: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 12.0,
                ),
              ),
            ),
          ),
          if (widget.suffix != null) widget.suffix!,
        ],
      ),
    );
  }
}

/// An informative, non-clickable row used for info rows inside a [FormCard].
class FormInfoRow extends StatelessWidget {
  const FormInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    this.badgeColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? badge;
  final Color? badgeColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 14.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.bodySmallMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.0,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? colors.accent)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          badge!,
                          style: AppTypography.caption.copyWith(
                            color: badgeColor ?? colors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4.0),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
