import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../application/markdown_table_controller.dart';
import '../../../application/smart_table_edits.dart';

/// Compact controls shared by inline and expanded workspaces.
class SmartTableControls extends StatelessWidget {
  const SmartTableControls({super.key,required this.controller});
  final MarkdownTableController controller;
  @override
  Widget build(BuildContext context) {
    final summary=controller.quickSummary;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing:8,
      children:[
        if(controller.hasRangeSelection) Text('Sum ${summary.result('SUM')} · Average ${summary.result('AVERAGE')} · Min ${summary.result('MIN')} · Max ${summary.result('MAX')} · Count ${summary.result('COUNT')}${summary.excludedErrors>0 ? ' · ${summary.excludedErrors} errors excluded':''}'),
        PopupMenuButton<String>(
          tooltip:'Smart table actions',
          icon:const Icon(Icons.functions,size:18),
          onSelected:(action) async {
            if(action.startsWith('summary:')) controller.createSummary(action.substring(8));
            if(action=='select_column') {
              final c=controller.activePosition.column;
              controller.selectRange(controller.activePosition.copyWith(row:1,column:c),controller.activePosition.copyWith(row:controller.table.rowCount-(controller.hasSummary ? 2:1),column:c));
            }
            if(action=='copy_sum') await Clipboard.setData(ClipboardData(text:summary.result('SUM')));
            if(action=='copy_raw') await Clipboard.setData(ClipboardData(text:controller.selectionTsv()));
            if(action=='copy_display') await Clipboard.setData(ClipboardData(text:controller.selectionTsv(displayed:true)));
            if(action=='insert_sum') controller.insertQuickFormula('SUM');
          },
          itemBuilder:(_)=>[
            const PopupMenuItem(value:'select_column',child:Text('Select data column')),
            const PopupMenuItem(value:'copy_raw',child:Text('Copy raw selection')),
            const PopupMenuItem(value:'copy_display',child:Text('Copy displayed selection')),
            if(controller.hasRangeSelection) ...[
              const PopupMenuItem(value:'copy_sum',child:Text('Copy sum')),
              const PopupMenuItem(value:'insert_sum',child:Text('Insert SUM below selection')),
            ],
            for(final op in SmartTableEdits.operations) PopupMenuItem(value:'summary:$op',child:Text('Summary row: $op')),
          ],
        ),
      ],
    );
  }
}
