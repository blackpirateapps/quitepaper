import 'smart_table_display.dart';
import '../domain/smart_tables/formula_engine.dart';
import 'smart_table_markdown.dart';
import 'smart_table_edits.dart';
import 'package:flutter/material.dart';
import '../domain/markdown_styles.dart';
import '../domain/markdown_table.dart';
import '../domain/markdown_table_alignment.dart';
import '../domain/markdown_table_position.dart';
import 'markdown_editing_controller.dart';
import 'markdown_table_formatter.dart';
import 'markdown_table_parser.dart';

/// State controller managing the active hybrid table editor session.
/// Coordinates active cell focus, keyboard navigation (Tab/Shift+Tab/Enter),
/// and source transformations back to the canonical Markdown document.
class MarkdownTableController extends ChangeNotifier {
  MarkdownTableController({
    required this.table,
    required this.getDocumentValue,
    required this.onUpdateDocument,
    TablePosition? initialPosition,
    this.styles,
  })  : _activePosition = initialPosition ?? const TablePosition(row: 0, column: 0) {
    _initCellController();
    _editStartText = _cellController.text;
    calculations = FormulaEngine(tableRawCells(table));
  }

  static const _parser = MarkdownTableParser();

  MarkdownTable table;
  late final FormulaEngine calculations;
  TablePosition? _selectionAnchor;
  TableRange get selectedRange => TableRange(_selectionAnchor ?? _activePosition, _activePosition);
  bool get hasRangeSelection => _selectionAnchor != null && (_selectionAnchor != _activePosition);
  TableQuickSummary get quickSummary => TableQuickSummary(calculations, selectedRange);
  final List<TextEditingValue> _undo = [], _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  String _editStartText = '';

  SmartTableMetadata get smartMetadata => SmartTableMetadata.read(getDocumentValue().text, table);
  bool get hasSummary => SmartTableEdits.hasSummary(tableRawCells(table), smartMetadata);

  void _publish(TextEditingValue value, {bool syncCell = false}) {
    final old = getDocumentValue();
    if (old.text == value.text) return;
    _undo.add(old);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    table = _parser.findTableAtOffset(value.text, table.sourceStart) ?? table;
    calculations.update(tableRawCells(table));
    onUpdateDocument(value);
    if (syncCell) reloadFrom(value);
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(getDocumentValue());
    final value = _undo.removeLast();
    onUpdateDocument(value); reloadFrom(value);
  }
  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(getDocumentValue());
    final value = _redo.removeLast();
    onUpdateDocument(value); reloadFrom(value);
  }
  void selectThrough(TablePosition position) {
    final anchor = _selectionAnchor ?? _activePosition;
    setActivePosition(position);
    _selectionAnchor = anchor;
    navigationMode=true;
    notifyListeners();
  }
  void selectRange(TablePosition start,TablePosition end) {
    setActivePosition(end); _selectionAnchor=start; navigationMode=true; notifyListeners();
  }
  String selectionTsv({bool displayed=false}) => [
    for(var r=selectedRange.top;r<=selectedRange.bottom;r++) [
      for(var c=selectedRange.left;c<=selectedRange.right;c++)
        displayed ? displayedCell(r,c) : table.getCell(r,c)?.trimmedText ?? '',
    ].join('\t'),
  ].join('\n');
  void applyDocumentValue(TextEditingValue value) => _publish(value,syncCell:true);
  void pasteCells(List<List<String>> cells) => _publish(SmartTableEdits.paste(getDocumentValue().text,table,_activePosition,cells),syncCell:true);
  void createSummary(String operation) => _publish(SmartTableEdits.summary(getDocumentValue().text,table,_activePosition.column,operation),syncCell:true);
  void insertQuickFormula(String operation) {
    final formula = '=$operation(${selectedRange.a1})';
    final target = selectedRange.bottom + 1;
    if(target >= table.rowCount) {
      var value=SmartTableEdits.structure(getDocumentValue().text,table,rows:true,index:table.rowCount,delete:false);
      final projection=_parser.findTableAtOffset(value.text,table.sourceStart)!;
      value=MarkdownTableFormatter.updateCell(value:value,table:projection,row:target,column:selectedRange.left,newCellText:formula);
      _publish(value,syncCell:true);
    } else {
      _publish(MarkdownTableFormatter.updateCell(value:getDocumentValue(),table:table,row:target,column:selectedRange.left,newCellText:formula),syncCell:true);
    }
  }
  void cancelCellEdit() {
    _cellController.text=_editStartText;
    _cellController.selection=TextSelection.collapsed(offset:_cellController.text.length);
  }
  void fillCalculatedColumn({bool reapply=false}) => _publish(SmartTableEdits.calculatedColumn(getDocumentValue().text,table,_activePosition.row,_activePosition.column,reapply:reapply),syncCell:true);
  void setNumericFormat(Map<String,dynamic> config) => _publish(SmartTableEdits.format(getDocumentValue().text,table,_activePosition.column,config),syncCell:true);


  String displayedCell(int row, int column, {String? locale}) {
    final raw = table.getCell(row,column)?.trimmedText ?? '';
    final config = smartMetadata.section('formats')['$column'];
    if (config != null || raw.startsWith('=') || raw.startsWith("'=")) {
      return SmartTableDisplay.format(calculations.value(row,column),config,locale:locale);
    }
    return raw;
  }

  TablePosition _activePosition;
  TablePosition get activePosition => _activePosition;

  final TextEditingValue Function() getDocumentValue;
  final void Function(TextEditingValue newValue) onUpdateDocument;
  final MarkdownStyles? styles;

  late MarkdownEditingController _cellController;
  MarkdownEditingController get cellController => _cellController;

  final Map<TablePosition, FocusNode> _cellFocusNodes = {};

  FocusNode getFocusNodeFor(TablePosition pos) {
    return _cellFocusNodes.putIfAbsent(
      pos,
      () => FocusNode(debugLabel: 'table_cell_${pos.row}_${pos.column}'),
    );
  }

  FocusNode get cellFocusNode => getFocusNodeFor(_activePosition);

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;
  bool navigationMode = false;
  void startEditing() { navigationMode=false; notifyListeners(); cellFocusNode.requestFocus(); }
  void stopEditing() { navigationMode=true; cellFocusNode.unfocus(); notifyListeners(); }
  bool _isInternalSync = false;

  void _initCellController() {
    final cell = table.getCell(_activePosition.row, _activePosition.column);
    final initialText = cell?.trimmedText ?? '';

    _cellController = MarkdownEditingController(
      text: initialText,
      styles: styles,
    );
    _cellController.addListener(_onCellTextChanged);
  }

  void updateTableProjection(MarkdownTable newTable) {
    table = newTable;
    // Bound active position to valid coordinates
    final validRow = _activePosition.row.clamp(0, table.rowCount - 1);
    final validCol = _activePosition.column.clamp(0, table.columnCount - 1);
    _activePosition = TablePosition(row: validRow, column: validCol);
    calculations.update(tableRawCells(table));
    _pruneDeadFocusNodes();
    notifyListeners();
  }

  void _pruneDeadFocusNodes() {
    _cellFocusNodes.removeWhere((pos, fn) {
      if (pos.row >= table.rowCount || pos.column >= table.columnCount) {
        fn.dispose();
        return true;
      }
      return false;
    });
  }

  void _onCellTextChanged() {
    if (_isInternalSync || _isDisposed || _cellController.value.composing.isValid && !_cellController.value.composing.isCollapsed) return;

    final cell = table.getCell(_activePosition.row, _activePosition.column);
    if (cell == null) return;

    final currentCellText = cell.trimmedText;
    final newCellText = _cellController.text;

    if (currentCellText == newCellText) return;

    final docVal = getDocumentValue();
    final updatedDocVal = SmartTableEdits.updateCell(docVal.text,table,_activePosition.row,_activePosition.column,newCellText);

    // Reparse the table from the updated document
    final reloadedTable = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloadedTable != null) {
      table = reloadedTable;
    }

    _publish(updatedDocVal);
  }

  void setActivePosition(TablePosition position) {
    if (_isDisposed) return;
    if (_activePosition == position) {
      final currentNode = getFocusNodeFor(position);
      if (!currentNode.hasFocus) {
        currentNode.requestFocus();
      }
      return;
    }

    _selectionAnchor = null;
    // Flush any changes before switching cell
    final targetRow = position.row.clamp(0, table.rowCount - 1);
    final targetCol = position.column.clamp(0, table.columnCount - 1);
    final newPos = TablePosition(row: targetRow, column: targetCol);

    _activePosition = newPos;

    final cell = table.getCell(targetRow, targetCol);
    final cellText = cell?.trimmedText ?? '';
    _editStartText = cellText;

    _isInternalSync = true;
    _cellController.text = cellText;
    _cellController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: cellText.length,
    );
    _isInternalSync = false;

    notifyListeners();

    final targetNode = getFocusNodeFor(newPos);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && targetNode.canRequestFocus && !targetNode.hasFocus) {
        targetNode.requestFocus();
      }
    });
  }

  /// Advances to the next cell (Tab). If at the final cell of the table, inserts a new row.
  void moveToNextCell({bool createRowIfLast = true}) {
    final row = _activePosition.row;
    final col = _activePosition.column;

    if (col < table.columnCount - 1) {
      setActivePosition(TablePosition(row: row, column: col + 1));
    } else if (hasSummary && row == table.rowCount-2 && createRowIfLast) {
      addRowBelow();
      setActivePosition(TablePosition(row: row+1, column:0));
    } else if (row < table.rowCount - 1) {
      setActivePosition(TablePosition(row: row + 1, column: 0));
    } else if (createRowIfLast) {
      addRowBelow();
      setActivePosition(TablePosition(row: table.rowCount - 1, column: 0));
    }
  }

  /// Moves to the previous cell (Shift+Tab).
  void moveToPreviousCell() {
    final row = _activePosition.row;
    final col = _activePosition.column;

    if (col > 0) {
      setActivePosition(TablePosition(row: row, column: col - 1));
    } else if (row > 0) {
      setActivePosition(TablePosition(row: row - 1, column: table.columnCount - 1));
    }
  }

  /// Moves to the cell directly above.
  void moveToCellAbove() {
    final row = _activePosition.row;
    final col = _activePosition.column;

    if (row > 0) {
      setActivePosition(TablePosition(row: row - 1, column: col));
    }
  }

  /// Moves to the cell directly below (Enter).
  void moveToCellBelow({bool createRowIfLast = false}) {
    final row = _activePosition.row;
    final col = _activePosition.column;

    if (row < table.rowCount - 1) {
      setActivePosition(TablePosition(row: row + 1, column: col));
    } else if (createRowIfLast) {
      addRowBelow();
      setActivePosition(TablePosition(row: table.rowCount - 1, column: col));
    }
  }

  /// Inserts a new row below the current active row.
  void addRowBelow() {
    final docVal = getDocumentValue();
    final updatedDocVal = SmartTableEdits.structure(docVal.text, table, rows:true, index:_activePosition.row+1, delete:false);

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetRow = (_activePosition.row + 1).clamp(0, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Inserts a new row above the current active row (or as first body row if header active).
  void addRowAbove() {
    final afterIndex = _activePosition.row <= 1 ? 0 : _activePosition.row - 1;
    final docVal = getDocumentValue();
    final updatedDocVal = SmartTableEdits.structure(docVal.text, table, rows:true, index:afterIndex+1, delete:false);

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetRow = (afterIndex + 1).clamp(0, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Inserts a new column to the right of the current active column.
  void addColumnRight() {
    final docVal = getDocumentValue();
    final updatedDocVal = SmartTableEdits.structure(docVal.text, table, rows:false, index:_activePosition.column+1, delete:false);

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetCol = (_activePosition.column + 1).clamp(0, table.columnCount - 1);
    setActivePosition(TablePosition(row: _activePosition.row, column: targetCol));
  }

  /// Inserts a new column to the left of the current active column.
  void addColumnLeft() {
    final insertAfter = _activePosition.column <= 0 ? -1 : _activePosition.column - 1;
    final docVal = getDocumentValue();
    final updatedDocVal = SmartTableEdits.structure(docVal.text, table, rows:false, index:insertAfter+1, delete:false);

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetCol = (insertAfter + 1).clamp(0, table.columnCount - 1);
    setActivePosition(TablePosition(row: _activePosition.row, column: targetCol));
  }

  /// Sets column alignment for the current active column.
  void setColumnAlignment(MarkdownTableAlignment alignment) {
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.setColumnAlignment(
      value: docVal,
      table: table,
      columnIndex: _activePosition.column,
      alignment: alignment,
    );

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal);
    notifyListeners();
  }

  /// Deletes the current active body row.
  void deleteCurrentRow() {
    if (_activePosition.row == 0 || table.bodyRows.isEmpty) {
      return; // Protect header row
    }

    final docVal = getDocumentValue();
    final updatedDocVal = SmartTableEdits.structure(docVal.text, table, rows:true, index:_activePosition.row, delete:true);

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetRow = (_activePosition.row - 1).clamp(0, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Deletes the current active column.
  void deleteCurrentColumn() {
    if (table.columnCount <= 1) {
      return; // Protect final column
    }

    final docVal = getDocumentValue();
    final updatedDocVal = SmartTableEdits.structure(docVal.text, table, rows:false, index:_activePosition.column, delete:true);

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetCol = _activePosition.column.clamp(0, table.columnCount - 1);
    setActivePosition(TablePosition(row: _activePosition.row, column: targetCol));
  }

  /// Duplicates the current active row, inserting the copy directly below it.
  void duplicateCurrentRow() {
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.duplicateRow(
      value: docVal,
      table: table,
      rowIndex: _activePosition.row,
    );

    final reloaded = _parser.findTableAtOffset(updatedDocVal.text, table.sourceStart);
    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetRow = (_activePosition.row < 1 ? 1 : _activePosition.row + 1)
        .clamp(0, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Duplicates the current active column, inserting the copy to its right.
  void duplicateCurrentColumn() {
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.duplicateColumn(
      value: docVal,
      table: table,
      columnIndex: _activePosition.column,
    );

    final reloaded = _parser.findTableAtOffset(updatedDocVal.text, table.sourceStart);
    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetCol = (_activePosition.column + 1).clamp(0, table.columnCount - 1);
    setActivePosition(TablePosition(row: _activePosition.row, column: targetCol));
  }

  /// Moves the current active body row to visible [targetRowIndex] (1..N).
  void moveCurrentRow(int targetRowIndex) {
    if (_activePosition.row <= 0) return; // header is immovable
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.moveRow(
      value: docVal,
      table: table,
      fromRowIndex: _activePosition.row,
      toRowIndex: targetRowIndex,
    );

    final reloaded = _parser.findTableAtOffset(updatedDocVal.text, table.sourceStart);
    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetRow = targetRowIndex.clamp(1, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Moves the current active column to [targetColumnIndex].
  void moveCurrentColumn(int targetColumnIndex) {
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.moveColumn(
      value: docVal,
      table: table,
      fromColumnIndex: _activePosition.column,
      toColumnIndex: targetColumnIndex,
    );

    final reloaded = _parser.findTableAtOffset(updatedDocVal.text, table.sourceStart);
    if (reloaded != null) {
      table = reloaded;
    }

    _publish(updatedDocVal, syncCell:true);

    final targetCol = targetColumnIndex.clamp(0, table.columnCount - 1);
    setActivePosition(TablePosition(row: _activePosition.row, column: targetCol));
  }

  /// Replaces the active table projection and resynchronises the active cell
  /// controller. Used after an external structural rewrite (e.g. the full-screen
  /// editor or a paste) mutates the working Markdown directly.
  void reloadFrom(TextEditingValue docValue, {TablePosition? newActivePosition}) {
    final found = _parser.findTables(docValue.text);
    final reloaded = _parser.findTableAtOffset(docValue.text, table.sourceStart) ??
        (found.isNotEmpty ? found.first : null);
    if (reloaded == null) return;
    table = reloaded;
    final pos = newActivePosition ?? _activePosition;
    final r = pos.row.clamp(0, table.rowCount - 1);
    final c = pos.column.clamp(0, table.columnCount - 1);
    _activePosition = TablePosition(row: r, column: c);
    final cell = table.getCell(r, c);
    _isInternalSync = true;
    _cellController.text = cell?.trimmedText ?? '';
    _editStartText = _cellController.text;
    _isInternalSync = false;
    calculations.update(tableRawCells(table));
    _pruneDeadFocusNodes();
    notifyListeners();
  }

  /// Deletes the entire table.
  void deleteTable() {
    final docVal = getDocumentValue();
    final end=SmartTableMetadata.read(docVal.text,table).sourceEnd;
    final updatedDocVal=TextEditingValue(text:docVal.text.replaceRange(table.sourceStart,end,''));

    _publish(updatedDocVal);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cellController.removeListener(_onCellTextChanged);
    _cellController.dispose();
    for (final fn in _cellFocusNodes.values) {
      fn.dispose();
    }
    _cellFocusNodes.clear();
    super.dispose();
  }
}
