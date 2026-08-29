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
  }

  static const _parser = MarkdownTableParser();

  MarkdownTable table;

  TablePosition _activePosition;
  TablePosition get activePosition => _activePosition;

  final TextEditingValue Function() getDocumentValue;
  final void Function(TextEditingValue newValue) onUpdateDocument;
  final MarkdownStyles? styles;

  late MarkdownEditingController _cellController;
  MarkdownEditingController get cellController => _cellController;

  final FocusNode _cellFocusNode = FocusNode();
  FocusNode get cellFocusNode => _cellFocusNode;

  bool _isDisposed = false;
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
    notifyListeners();
  }

  void _onCellTextChanged() {
    if (_isInternalSync || _isDisposed) return;

    final cell = table.getCell(_activePosition.row, _activePosition.column);
    if (cell == null) return;

    final currentCellText = cell.trimmedText;
    final newCellText = _cellController.text;

    if (currentCellText == newCellText) return;

    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.updateCell(
      value: docVal,
      table: table,
      row: _activePosition.row,
      column: _activePosition.column,
      newCellText: newCellText,
    );

    // Reparse the table from the updated document
    final reloadedTable = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloadedTable != null) {
      table = reloadedTable;
    }

    onUpdateDocument(updatedDocVal);
  }

  void setActivePosition(TablePosition position) {
    if (_isDisposed) return;
    if (_activePosition == position) return;

    // Flush any changes before switching cell
    final targetRow = position.row.clamp(0, table.rowCount - 1);
    final targetCol = position.column.clamp(0, table.columnCount - 1);
    final newPos = TablePosition(row: targetRow, column: targetCol);

    _activePosition = newPos;

    final cell = table.getCell(targetRow, targetCol);
    final cellText = cell?.trimmedText ?? '';

    _isInternalSync = true;
    _cellController.text = cellText;
    _cellController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: cellText.length,
    );
    _isInternalSync = false;

    notifyListeners();

    if (!_cellFocusNode.hasFocus) {
      _cellFocusNode.requestFocus();
    }
  }

  /// Advances to the next cell (Tab). If at the final cell of the table, inserts a new row.
  void moveToNextCell({bool createRowIfLast = true}) {
    final row = _activePosition.row;
    final col = _activePosition.column;

    if (col < table.columnCount - 1) {
      setActivePosition(TablePosition(row: row, column: col + 1));
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
    final updatedDocVal = MarkdownTableFormatter.addRow(
      value: docVal,
      table: table,
      afterRowIndex: _activePosition.row,
    );

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    onUpdateDocument(updatedDocVal);

    final targetRow = (_activePosition.row + 1).clamp(0, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Inserts a new row above the current active row (or as first body row if header active).
  void addRowAbove() {
    final afterIndex = _activePosition.row <= 1 ? 0 : _activePosition.row - 1;
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.addRow(
      value: docVal,
      table: table,
      afterRowIndex: afterIndex,
    );

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    onUpdateDocument(updatedDocVal);

    final targetRow = (afterIndex + 1).clamp(0, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Inserts a new column to the right of the current active column.
  void addColumnRight() {
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.addColumn(
      value: docVal,
      table: table,
      afterColumnIndex: _activePosition.column,
    );

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    onUpdateDocument(updatedDocVal);

    final targetCol = (_activePosition.column + 1).clamp(0, table.columnCount - 1);
    setActivePosition(TablePosition(row: _activePosition.row, column: targetCol));
  }

  /// Inserts a new column to the left of the current active column.
  void addColumnLeft() {
    final insertAfter = _activePosition.column <= 0 ? -1 : _activePosition.column - 1;
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.addColumn(
      value: docVal,
      table: table,
      afterColumnIndex: insertAfter,
    );

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    onUpdateDocument(updatedDocVal);

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

    onUpdateDocument(updatedDocVal);
    notifyListeners();
  }

  /// Deletes the current active body row.
  void deleteCurrentRow() {
    if (_activePosition.row == 0 || table.bodyRows.isEmpty) {
      return; // Protect header row
    }

    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.deleteRow(
      value: docVal,
      table: table,
      rowIndex: _activePosition.row,
    );

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    onUpdateDocument(updatedDocVal);

    final targetRow = (_activePosition.row - 1).clamp(0, table.rowCount - 1);
    setActivePosition(TablePosition(row: targetRow, column: _activePosition.column));
  }

  /// Deletes the current active column.
  void deleteCurrentColumn() {
    if (table.columnCount <= 1) {
      return; // Protect final column
    }

    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.deleteColumn(
      value: docVal,
      table: table,
      columnIndex: _activePosition.column,
    );

    final reloaded = _parser.findTableAtOffset(
      updatedDocVal.text,
      table.sourceStart,
    );

    if (reloaded != null) {
      table = reloaded;
    }

    onUpdateDocument(updatedDocVal);

    final targetCol = _activePosition.column.clamp(0, table.columnCount - 1);
    setActivePosition(TablePosition(row: _activePosition.row, column: targetCol));
  }

  /// Deletes the entire table.
  void deleteTable() {
    final docVal = getDocumentValue();
    final updatedDocVal = MarkdownTableFormatter.deleteTable(
      value: docVal,
      table: table,
    );

    onUpdateDocument(updatedDocVal);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cellController.removeListener(_onCellTextChanged);
    _cellController.dispose();
    _cellFocusNode.dispose();
    super.dispose();
  }
}
