import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/settings/application/typography_provider.dart';
import '../../utils/font_family_helper.dart';
import '../text/attachment_csv_parser.dart';
import '../text/attachment_text_detector.dart';
import 'plain_text_viewer.dart';

/// Presentation mode for CSV and TSV attachments.
enum CsvViewMode {
  table,
  source,
}

/// Read-only viewer for CSV and TSV attachments supporting both Table grid
/// and Source (raw CSV text) presentation modes.
class CsvAttachmentViewer extends ConsumerStatefulWidget {
  const CsvAttachmentViewer({
    super.key,
    required this.rawCsvText,
    required this.mode,
    this.delimiter = ',',
    this.searchQuery,
    this.currentMatchIndex = 0,
    this.onMatchesCountChanged,
    this.wordWrap,
    this.showLineNumbers,
    this.scrollController,
  });

  final String rawCsvText;
  final CsvViewMode mode;
  final String delimiter;
  final String? searchQuery;
  final int currentMatchIndex;
  final ValueChanged<int>? onMatchesCountChanged;
  final bool? wordWrap;
  final bool? showLineNumbers;
  final ScrollController? scrollController;

  @override
  ConsumerState<CsvAttachmentViewer> createState() => _CsvAttachmentViewerState();
}

class _CsvAttachmentViewerState extends ConsumerState<CsvAttachmentViewer> {
  late CsvTableData _tableData;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  @override
  void didUpdateWidget(CsvAttachmentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawCsvText != widget.rawCsvText || oldWidget.delimiter != widget.delimiter) {
      _parseData();
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _parseData() {
    _tableData = AttachmentCsvParser.parse(
      widget.rawCsvText,
      delimiter: widget.delimiter,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == CsvViewMode.source) {
      return PlainTextViewer(
        text: widget.rawCsvText,
        format: widget.delimiter == '\t' ? TextAttachmentFormat.tsv : TextAttachmentFormat.csv,
        isMonospaced: true,
        showLineNumbers: widget.showLineNumbers ?? true,
        wordWrap: widget.wordWrap ?? false,
        searchQuery: widget.searchQuery,
        currentMatchIndex: widget.currentMatchIndex,
        onMatchesCountChanged: widget.onMatchesCountChanged,
        scrollController: widget.scrollController,
      );
    }

    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);

    if (_tableData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_chart_outlined, size: 40, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Empty spreadsheet',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final query = widget.searchQuery?.trim().toLowerCase();
    final fontFamily = typography.bodyFontFamily;
    final baseFontSize = typography.fontSize;

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SelectionArea(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: colors.divider, width: 0.8),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    colors.accent.withValues(alpha: 0.08),
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return colors.accent.withValues(alpha: 0.05);
                    }
                    return null;
                  }),
                  dividerThickness: 0.8,
                  horizontalMargin: AppSpacing.md,
                  columnSpacing: AppSpacing.lg,
                  columns: List.generate(_tableData.columnCount, (colIdx) {
                    final headerText = colIdx < _tableData.headers.length
                        ? _tableData.headers[colIdx]
                        : 'Col ${colIdx + 1}';

                    return DataColumn(
                      label: Text(
                        headerText,
                        style: FontFamilyHelper.getTextStyle(
                          fontFamily: typography.headingFontFamily ?? fontFamily,
                          baseStyle: TextStyle(
                            fontSize: baseFontSize * 0.95,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                  rows: List.generate(_tableData.rowCount, (rowIdx) {
                    final row = _tableData.rows[rowIdx];
                    return DataRow(
                      cells: List.generate(_tableData.columnCount, (colIdx) {
                        final cellText = colIdx < row.length ? row[colIdx] : '';
                        final isMatch = query != null &&
                            query.isNotEmpty &&
                            cellText.toLowerCase().contains(query);

                        return DataCell(
                          Container(
                            padding: isMatch
                                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                                : EdgeInsets.zero,
                            decoration: isMatch
                                ? BoxDecoration(
                                    color: colors.accent.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(AppRadii.sm / 2),
                                  )
                                : null,
                            child: Text(
                              cellText,
                              style: FontFamilyHelper.getTextStyle(
                                fontFamily: fontFamily,
                                baseStyle: TextStyle(
                                  fontSize: baseFontSize * 0.9,
                                  fontWeight: isMatch ? FontWeight.w600 : FontWeight.normal,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          onLongPress: () async {
                            await Clipboard.setData(ClipboardData(text: cellText));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied "$cellText"'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
