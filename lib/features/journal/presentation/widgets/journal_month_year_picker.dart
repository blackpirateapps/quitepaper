import 'package:flutter/material.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';

/// Modal dialog for quickly navigating across years and months in the journal calendar.
class JournalMonthYearPicker extends StatefulWidget {
  const JournalMonthYearPicker({
    super.key,
    required this.initialYear,
    required this.initialMonth,
    required this.onMonthSelected,
  });

  final int initialYear;
  final int initialMonth;
  final void Function(int year, int month) onMonthSelected;

  static Future<void> show(
    BuildContext context, {
    required int initialYear,
    required int initialMonth,
    required void Function(int year, int month) onMonthSelected,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => JournalMonthYearPicker(
        initialYear: initialYear,
        initialMonth: initialMonth,
        onMonthSelected: onMonthSelected,
      ),
    );
  }

  @override
  State<JournalMonthYearPicker> createState() => _JournalMonthYearPickerState();
}

class _JournalMonthYearPickerState extends State<JournalMonthYearPicker> {
  late int _selectedYear;
  late int _selectedMonth;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    final isCurrentYear = _selectedYear == now.year;

    return Dialog(
      backgroundColor: colors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderLg,
        side: BorderSide(color: colors.divider, width: 0.8),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Year Selector Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  QuietIconButton(
                    icon: PhosphorIconsRegular.caretLeft,
                    tooltip: 'Previous year',
                    onPressed: () {
                      setState(() {
                        _selectedYear--;
                      });
                    },
                  ),
                  Text(
                    '$_selectedYear',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  QuietIconButton(
                    icon: PhosphorIconsRegular.caretRight,
                    tooltip: 'Next year',
                    onPressed: () {
                      setState(() {
                        _selectedYear++;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Divider(color: colors.divider, height: 1, thickness: 0.8),
              const SizedBox(height: AppSpacing.sm),

              // 4x3 Month Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthNum = index + 1;
                  final monthName = _monthNames[index];
                  final isSelected = _selectedYear == widget.initialYear && monthNum == _selectedMonth;
                  final isCurrentMonth = isCurrentYear && monthNum == now.month;

                  return Material(
                    color: isSelected
                        ? colors.accent.withValues(alpha: 0.15)
                        : (isCurrentMonth ? colors.surfaceSubtle : Colors.transparent),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      onTap: () {
                        widget.onMonthSelected(_selectedYear, monthNum);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: isSelected
                              ? Border.all(color: colors.accent, width: 1.0)
                              : (isCurrentMonth
                                  ? Border.all(color: colors.divider, width: 0.8)
                                  : null),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthName,
                          style: AppTypography.bodySmall.copyWith(
                            color: isSelected
                                ? colors.accent
                                : (isCurrentMonth ? colors.textPrimary : colors.textSecondary),
                            fontWeight: isSelected || isCurrentMonth ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.divider, height: 1, thickness: 0.8),
              const SizedBox(height: AppSpacing.xs),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      final currentYear = now.year;
                      final currentMonth = now.month;
                      widget.onMonthSelected(currentYear, currentMonth);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Current Month',
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
