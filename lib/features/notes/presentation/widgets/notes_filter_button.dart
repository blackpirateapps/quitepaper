import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/quiet_icon_button.dart';

/// Filter button displaying an accessible filter icon with a subtle badge when advanced filters are active.
class NotesFilterButton extends StatelessWidget {
  const NotesFilterButton({
    super.key,
    required this.onPressed,
    required this.advancedFilterCount,
  });

  final VoidCallback onPressed;
  final int advancedFilterCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasFilters = advancedFilterCount > 0;
    final semanticsLabel = hasFilters
        ? 'Filter notes, $advancedFilterCount active filter${advancedFilterCount == 1 ? '' : 's'}'
        : 'Filter notes';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          QuietIconButton(
            icon: Icons.filter_list_rounded,
            tooltip: semanticsLabel,
            onPressed: onPressed,
          ),
          if (hasFilters)
            Positioned(
              top: 7,
              right: 7,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      advancedFilterCount > 9 ? '9+' : '$advancedFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
