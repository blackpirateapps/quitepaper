import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

class NoteDateHeader extends StatelessWidget {
  const NoteDateHeader({
    super.key,
    required this.title,
    this.isFirst = false,
  });

  final String title;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: isFirst ? AppSpacing.md : AppSpacing.xl,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTypography.headline.copyWith(
          color: colors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
