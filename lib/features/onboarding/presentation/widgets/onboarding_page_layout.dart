import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

class OnboardingPageLayout extends StatelessWidget {
  const OnboardingPageLayout({
    super.key,
    this.eyebrow,
    required this.title,
    required this.body,
    this.visual,
    this.extra,
    this.belowBody,
    this.footnote,
    this.visualFirst = false,
  });

  final String? eyebrow;
  final String title;
  final String body;
  final Widget? visual;
  final Widget? extra;
  final Widget? belowBody;
  final String? footnote;
  final bool visualFirst;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isWide = width >= 760;
        final horizontalPadding = width >= 700 ? 40.0 : 24.0;
        final rightSide = visual ?? extra;

        final copyWidget = _buildCopyColumn(context, colors, isWide);

        Widget content;
        if (isWide && rightSide != null) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: copyWidget,
              ),
              const SizedBox(width: 48),
              Expanded(
                flex: 6,
                child: Center(child: rightSide),
              ),
            ],
          );
        } else {
          final List<Widget> children = [];
          if (visualFirst && visual != null) {
            children.add(Center(child: visual!));
            children.add(const SizedBox(height: 28));
            children.add(copyWidget);
          } else {
            children.add(copyWidget);
            if (rightSide != null) {
              children.add(const SizedBox(height: 28));
              children.add(Center(child: rightSide));
            }
          }

          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: 8,
            bottom: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCopyColumn(BuildContext context, AppColors colors, bool isWide) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null && eyebrow!.isNotEmpty) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: AppTypography.caption.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.display.copyWith(
              fontSize: isWide ? 40 : 34,
              fontWeight: FontWeight.w700,
              height: 1.14,
              letterSpacing: -0.6,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          body,
          style: isWide
              ? AppTypography.bodyLarge.copyWith(
                  color: colors.textSecondary,
                  height: 1.55,
                )
              : TextStyle(
                  fontSize: 17,
                  height: 1.55,
                  color: colors.textSecondary,
                ),
        ),
        if (belowBody != null) ...[
          belowBody!,
        ],
        if (footnote != null) ...[
          const SizedBox(height: 16),
          Text(
            footnote!,
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textTertiary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}
