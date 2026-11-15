import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../application/markdown_table_controller.dart';
import '../../../application/smart_table_edits.dart';

/// Compact controls shared by inline and expanded workspaces.
class SmartTableControls extends StatelessWidget {
  const SmartTableControls({super.key, required this.controller});
  final MarkdownTableController controller;
  @override
  Widget build(BuildContext context) {
    final summary = controller.quickSummary;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        if (controller.operationError != null)
          Text(
            '${controller.operationError} Table edit exceeds the supported limits.',
          ),
        if (!controller.smartMetadata.editable)
          const Text(
            'Table settings preserved; review annotation in Markdown.',
          ),
        if (controller.smartMetadata
            .section('calculatedColumns')
            .containsKey('${controller.activePosition.column}'))
          const Text('ƒ Calculated column'),
        if (controller.hasRangeSelection)
          Text(
            'Sum ${summary.result('SUM')} · Average ${summary.result('AVERAGE')} · Min ${summary.result('MIN')} · Max ${summary.result('MAX')} · Count ${summary.result('COUNT')}${summary.excludedErrors > 0 ? ' · ${summary.excludedErrors} errors excluded' : ''}',
          ),
        PopupMenuButton<String>(
          tooltip: 'Smart table actions',
          icon: const Icon(Icons.functions, size: 18),
          onSelected: (action) async {
            if (action.startsWith('summary:')) {
              controller.createSummary(action.substring(8));
            }
            if (action == 'select_column') {
              final c = controller.activePosition.column;
              controller.selectRange(
                controller.activePosition.copyWith(row: 1, column: c),
                controller.activePosition.copyWith(
                  row:
                      controller.table.rowCount -
                      (controller.hasSummary ? 2 : 1),
                  column: c,
                ),
              );
            }
            if (action.startsWith('copy:')) {
              await Clipboard.setData(
                ClipboardData(text: summary.result(action.substring(5))),
              );
            }
            if (action == 'copy_raw') {
              await Clipboard.setData(
                ClipboardData(text: controller.selectionTsv()),
              );
            }
            if (action == 'copy_display') {
              await Clipboard.setData(
                ClipboardData(text: controller.selectionTsv(displayed: true)),
              );
            }
            if (action.startsWith('insert:')) {
              controller.insertQuickFormula(action.substring(7));
            }
            if ((action == 'fill' || action == 'reapply') && context.mounted) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    action == 'fill'
                        ? 'Calculate this column?'
                        : 'Reapply column formula?',
                  ),
                  content: Text(
                    action == 'fill'
                        ? 'Fill blank data cells using this formula. New rows will use relative copies.'
                        : 'Replace every data cell in this column with a relative copy of this formula.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && !controller.isDisposed) {
                controller.fillCalculatedColumn(reapply: action == 'reapply');
              }
            }
            if (action == 'format' && context.mounted) {
              await _formatDialog(context);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'select_column',
              enabled: controller.table.rowCount > 1,
              child: const Text('Select data column'),
            ),
            const PopupMenuItem(
              value: 'copy_raw',
              child: Text('Copy raw selection'),
            ),
            const PopupMenuItem(
              value: 'copy_display',
              child: Text('Copy displayed selection'),
            ),
            if (controller.hasRangeSelection) ...[
              for (final op in SmartTableEdits.operations)
                PopupMenuItem(value: 'copy:$op', child: Text('Copy $op value')),
              for (final op in SmartTableEdits.operations)
                PopupMenuItem(
                  value: 'insert:$op',
                  child: Text('Insert $op below selection'),
                ),
            ],
            PopupMenuItem(
              value: 'fill',
              enabled: controller.smartMetadata.editable,
              child: const Text('Calculate column · fill blanks…'),
            ),
            PopupMenuItem(
              value: 'reapply',
              enabled: controller.smartMetadata.editable,
              child: const Text('Reapply column formula…'),
            ),
            PopupMenuItem(
              value: 'format',
              enabled: controller.smartMetadata.editable,
              child: const Text('Number format…'),
            ),
            for (final op in SmartTableEdits.operations)
              PopupMenuItem(
                value: 'summary:$op',
                enabled: controller.smartMetadata.editable,
                child: Text('Summary row: $op'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _formatDialog(BuildContext context) async {
    final existing = controller.smartMetadata.section(
      'formats',
    )['${controller.activePosition.column}'];
    var type = existing is Map && existing['type'] is String
        ? existing['type'] as String
        : 'number';
    var digits = existing is Map && existing['digits'] is int
        ? (existing['digits'] as int).clamp(0, 18)
        : 2;
    var currency = existing is Map && existing['currency'] is String
        ? existing['currency'] as String
        : 'USD';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Column number format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value:
                    const [
                      'number',
                      'decimal',
                      'currency',
                      'percent',
                    ].contains(type)
                    ? type
                    : 'number',
                isExpanded: true,
                items: [
                  for (final option in const [
                    'number',
                    'decimal',
                    'currency',
                    'percent',
                  ])
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (v) => setState(() => type = v!),
              ),
              Row(
                children: [
                  const Text('Decimal places'),
                  IconButton(
                    tooltip: 'Fewer decimals',
                    onPressed: () =>
                        setState(() => digits = (digits - 1).clamp(0, 18)),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$digits'),
                  IconButton(
                    tooltip: 'More decimals',
                    onPressed: () =>
                        setState(() => digits = (digits + 1).clamp(0, 18)),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (type == 'currency')
                TextFormField(
                  initialValue: currency,
                  onChanged: (value) => currency = value,
                  decoration: const InputDecoration(
                    labelText: 'ISO currency code (INR, USD…)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final code = currency.trim().toUpperCase();
                if (type == 'currency' && !RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
                  return;
                }
                Navigator.pop(context, {
                  'type': type,
                  if (type != 'number') 'digits': digits,
                  if (type == 'currency') 'currency': code,
                });
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null && !controller.isDisposed) {
      controller.setNumericFormat(result);
    }
  }
}
