import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/markdown_table.dart';
import '../domain/markdown_table_position.dart';
import '../domain/smart_tables/formula_engine.dart';
import 'markdown_table_formatter.dart';
import 'markdown_table_parser.dart';
import 'smart_table_markdown.dart';

/// Ignorable, table-adjacent metadata. Unknown versions and malformed comments
/// are opaque: source edits keep them, configuration edits refuse to replace them.
class SmartTableMetadata {
  SmartTableMetadata(this.data, {this.opaque = '', this.sourceEnd = 0});
  final Map<String, dynamic> data;
  final String opaque;
  final int sourceEnd;
  bool get editable => opaque.isEmpty;
  static final annotation = RegExp(r'^\r?\n(<!-- quiet-paper-table:([\w.-]+)[\s\S]*?-->)');
  static SmartTableMetadata read(String source, MarkdownTable table) {
    final m = annotation.firstMatch(source.substring(table.sourceEnd));
    if (m == null) return SmartTableMetadata({}, sourceEnd: table.sourceEnd);
    final raw = m[1]!;
    final end = table.sourceEnd + m.end;
    if (m[2] == 'v1' && raw.length <= 16384) {
      try {
        final json = raw.substring('<!-- quiet-paper-table:v1'.length, raw.length - 3).trim();
        final decoded = jsonDecode(json);
        if (decoded is Map<String, dynamic>) return SmartTableMetadata(decoded, sourceEnd:end);
      } catch (_) { /* Content is retained opaquely. */ }
    }
    return SmartTableMetadata({}, opaque: raw, sourceEnd:end);
  }
  Map<String,dynamic> section(String key) => data[key] is Map<String,dynamic> ? Map<String,dynamic>.from(data[key]) : {};
  String encode() {
    if (!editable) return '\n$opaque';
    if (data.isEmpty) return '';
    data.putIfAbsent('id', () => 'qt_${DateTime.now().microsecondsSinceEpoch}');
    final json = jsonEncode(data).replaceAll('>', r'\u003e').replaceAll('<', r'\u003c');
    if (json.length > 16000) throw const FormulaFailure('#LIMIT!');
    return '\n<!-- quiet-paper-table:v1 $json -->';
  }
}

class TableRange {
  TableRange(TablePosition a, TablePosition b)
      : top = a.row < b.row ? a.row : b.row,
        bottom = a.row > b.row ? a.row : b.row,
        left = a.column < b.column ? a.column : b.column,
        right = a.column > b.column ? a.column : b.column;
  final int top,bottom,left,right;
  bool contains(int row,int column) => row >= top && row <= bottom && column >= left && column <= right;
  String get a1 => '${CellAddress(top,left).label}:${CellAddress(bottom,right).label}';
}

class TableQuickSummary {
  TableQuickSummary(FormulaEngine engine, TableRange range) {
    for (var r=range.top; r<=range.bottom; r++) {
      for (var c=range.left; c<=range.right; c++) {
        final value = engine.value(r,c);
        if (value.number != null) numbers.add(value.number!);
        if (value.kind == CellValueKind.error) excludedErrors++;
      }
    }
  }
  final numbers = <TableDecimal>[];
  int excludedErrors = 0;
  String result(String operation) {
    try { return FormulaEngine.aggregate(operation,numbers).toString(); }
    on FormulaFailure catch (e) { return e.code; }
  }
}

/// Pure edit planner. One returned TextEditingValue contains raw cells,
/// rewritten references, and annotation changes for one editor history step.
abstract final class SmartTableEdits {
  static const operations = ['SUM','AVERAGE','MIN','MAX','COUNT'];
  static TextEditingValue write(String source, MarkdownTable table,
      List<List<String>> cells, SmartTableMetadata metadata, {List<String>? alignments}) {
    if (cells.isEmpty || cells.length * cells.first.length > FormulaEngine.maxCells || cells.first.length > 256) throw const FormulaFailure('#LIMIT!');
    String row(List<String> values) => '| ${values.map(MarkdownTableFormatter.escapeCellContent).join(' | ')} |';
    final delimiter = alignments ?? [for (var c=0;c<cells.first.length;c++) table.getAlignment(c).toDelimiterString()];
    final block = [row(cells.first), '| ${delimiter.join(' | ')} |', ...cells.skip(1).map(row)].join('\n') + metadata.encode();
    return TextEditingValue(text: source.replaceRange(table.sourceStart, metadata.sourceEnd, block), selection: TextSelection.collapsed(offset:table.sourceStart));
  }

  static bool hasSummary(List<List<String>> cells, SmartTableMetadata metadata) {
    final summary = metadata.section('summary');
    final recorded = summary['cells'];
    if (cells.length < 2 || recorded is! List || recorded.length != cells.last.length) return false;
    return List.generate(cells.last.length,(c)=>recorded[c]==cells.last[c]).every((e)=>e);
  }

  static TextEditingValue updateCell(String source,MarkdownTable table,int row,int column,String text) {
    final meta=SmartTableMetadata.read(source,table), cells=tableRawCells(table);
    final valid=hasSummary(cells,meta);
    final value=MarkdownTableFormatter.updateCell(value:TextEditingValue(text:source),table:table,row:row,column:column,newCellText:text);
    if(!valid || row!=cells.length-1 || !meta.editable) return value;
    // An intentional override opts this summary cell out of regeneration.
    final summary=meta.section('summary');
    final ops=summary['operations'] is Map ? Map<String,dynamic>.from(summary['operations']):<String,dynamic>{};
    ops.remove('$column'); cells[row][column]=text;
    summary['operations']=ops; summary['cells']=[...cells.last]; meta.data['summary']=summary;
    return write(source,table,cells,meta);
  }

  static TextEditingValue summary(String source, MarkdownTable table, int column, String operation) {
    final meta = SmartTableMetadata.read(source,table);
    if (!meta.editable || !operations.contains(operation) || table.rowCount < 2) return TextEditingValue(text:source);
    final cells = tableRawCells(table);
    final valid = hasSummary(cells,meta);
    final summary = valid ? meta.section('summary') : <String,dynamic>{};
    if (!valid) cells.add(List.filled(table.columnCount,''));
    final ops = summary['operations'] is Map ? Map<String,dynamic>.from(summary['operations']) : <String,dynamic>{};
    ops['$column'] = operation;
    final letter = CellAddress.columnName(column);
    cells.last[column] = '=$operation(${letter}2:$letter${cells.length-1})';
    summary['operations'] = ops;
    summary['cells'] = [...cells.last];
    meta.data['summary'] = summary;
    return write(source,table,cells,meta);
  }

  static void _refreshSummary(List<List<String>> cells, SmartTableMetadata meta) {
    final summary = meta.section('summary');
    final ops = summary['operations'];
    if (ops is! Map) return;
    for (final entry in ops.entries) {
      final c = int.tryParse('${entry.key}');
      if (c == null || c < 0 || c >= cells.last.length || !operations.contains(entry.value)) continue;
      final letter = CellAddress.columnName(c);
      cells.last[c] = cells.length > 2 ? '=${entry.value}(${letter}2:$letter${cells.length-1})' : '=${entry.value}()';
    }
    summary['cells'] = [...cells.last];
    meta.data['summary'] = summary;
  }

  static TextEditingValue structure(String source, MarkdownTable table, {required bool rows, required int index, required bool delete}) {
    final cells = tableRawCells(table);
    final meta = SmartTableMetadata.read(source,table);
    final summary = hasSummary(cells,meta);
    if (rows) {
      if (delete && (index <= 0 || index >= cells.length)) return TextEditingValue(text:source);
      index = index.clamp(1, cells.length);
      if (summary && !delete && index >= cells.length-1) index = cells.length-1;
      if (delete) {
        cells.removeAt(index);
        if (summary && index == cells.length) meta.data.remove('summary');
      } else { cells.insert(index,List.filled(table.columnCount,'')); }
    } else {
      if (delete && table.columnCount<=1) return TextEditingValue(text:source);
      for (final row in cells) { if (delete) { row.removeAt(index); } else { row.insert(index,''); } }
    }
    for (var r=0;r<cells.length;r++) {
      for (var c=0;c<cells[r].length;c++) {
        cells[r][c] = FormulaReferences.structure(cells[r][c], rows:rows,index:index,delete:delete);
      }
    }
    // Existing optional metadata follows coordinates along with canonical cells.
    _rebaseMetadata(meta, rows: rows,index:index,delete:delete);
    if (rows && !delete) _fillNewRow(cells,meta,index);
    if (summary && meta.data.containsKey('summary')) _refreshSummary(cells,meta);
    final aligns = [for(var c=0;c<table.columnCount;c++) table.getAlignment(c).toDelimiterString()];
    if (!rows) { if (delete) { aligns.removeAt(index); } else { aligns.insert(index,'---'); } }
    return write(source,table,cells,meta,alignments:aligns);
  }

  static void _rebaseMetadata(SmartTableMetadata meta, {required bool rows,required int index,required bool delete}) {
    if (!meta.editable) return;
    for (final key in ['formats','calculatedColumns']) {
      final section = meta.section(key), changed = <String,dynamic>{};
      for (final entry in section.entries) {
        final col = int.tryParse(entry.key);
        if (col == null) { changed[entry.key]=entry.value; continue; }
        if (!rows && delete && col==index) continue;
        final newCol = !rows && col>=index ? col+(delete ? -1:1) : col;
        var value = entry.value;
        if (key=='calculatedColumns' && value is Map && value['formula'] is String && value['row'] is int) {
          value = Map<String,dynamic>.from(value);
          value['formula'] = FormulaReferences.structure(value['formula'],rows:rows,index:index,delete:delete);
          final wasRow=value['row'] as int;
          if (rows && wasRow>=index) value['row'] = wasRow+(delete ? -1:1);
          if (rows && delete && wasRow==index) {
            // Deleting a template row doesn't remove its intent; reanchor the
            // template at the next data row, preserving relative offsets.
            value['formula'] = FormulaReferences.shift(value['formula'],1,0);
            value['row'] = index;
          }
        }
        changed['$newCol']=value;
      }
      if (section.isNotEmpty) meta.data[key]=changed;
    }
    if (!rows) {
      final summary=meta.section('summary');
      if (summary['operations'] is Map) {
        final moved=<String,dynamic>{};
        for (final e in (summary['operations'] as Map).entries) {
          final c=int.tryParse('${e.key}');
          if(c==null || delete && c==index) continue;
          moved['${c>=index ? c+(delete ? -1:1):c}']=e.value;
        }
        summary['operations']=moved; meta.data['summary']=summary;
      }
    }
  }

  static void _fillNewRow(List<List<String>> cells,SmartTableMetadata meta,int row) {
    for (final entry in meta.section('calculatedColumns').entries) {
      final col=int.tryParse(entry.key), config=entry.value;
      if(col==null || col<0 || col>=cells[row].length || config is! Map || config['formula'] is! String || config['row'] is! int) continue;
      cells[row][col]=FormulaReferences.shift(config['formula'],row-(config['row'] as int),0);
    }
  }

  static TextEditingValue move(String source,MarkdownTable table,{required bool rows,required int from,required int to,bool promote=false}) {
    final cells=tableRawCells(table),meta=SmartTableMetadata.read(source,table);
    final summary=hasSummary(cells,meta);
    final max=rows ? cells.length-1-(summary ? 1:0):table.columnCount-1;
    final min=rows && !promote ? 1:0;
    if(from<min || from>max || to<min || to>max || from==to) return TextEditingValue(text:source);
    final order=List.generate(rows ? cells.length:table.columnCount,(i)=>i);
    if(promote) { final tmp=order[from]; order[from]=order[to]; order[to]=tmp; }
    else { order.insert(to,order.removeAt(from)); }
    int remap(int old)=>order.indexOf(old);
    final changed=rows ? [for(final r in order) [...cells[r]]] : [for(final row in cells) [for(final c in order) row[c]]];
    String rebase(String formula)=>FormulaReferences.rewrite(formula,(a)=>rows ? a.at(remap(a.row)<0 ? a.row:remap(a.row),a.column):a.at(a.row,remap(a.column)<0 ? a.column:remap(a.column)));
    for(final row in changed) { for(var c=0;c<row.length;c++) { row[c]=rebase(row[c]); } }
    for(final key in ['formats','calculatedColumns']) {
      final out=<String,dynamic>{};
      for(final entry in meta.section(key).entries) {
        final col=int.tryParse(entry.key);
        var config=entry.value;
        if(key=='calculatedColumns' && config is Map && config['formula'] is String && config['row'] is int) {
          config=Map<String,dynamic>.from(config);
          config['formula']=rebase(config['formula']);
          if(rows && remap(config['row'])>=0) config['row']=remap(config['row']);
        }
        out['${!rows && col!=null && remap(col)>=0 ? remap(col):entry.key}']=config;
      }
      if(out.isNotEmpty) meta.data[key]=out;
    }
    if(summary) {
      final config=meta.section('summary');
      if(!rows && config['operations'] is Map) {
        config['operations']={for(final entry in (config['operations'] as Map).entries) '${remap(int.parse(entry.key))}':entry.value};
      }
      meta.data['summary']=config;
      _refreshSummary(changed,meta);
    }
    final aligns=rows ? null:[for(final c in order) table.getAlignment(c).toDelimiterString()];
    return write(source,table,changed,meta,alignments:aligns);
  }

  static TextEditingValue duplicate(String source,MarkdownTable table,{required bool rows,required int index}) {
    final old=tableRawCells(table),oldMeta=SmartTableMetadata.read(source,table);
    if(rows && hasSummary(old,oldMeta) && index==old.length-1) return TextEditingValue(text:source);
    final inserted=structure(source,table,rows:rows,index:index+1,delete:false);
    final next=const MarkdownTableParser().findTableAtOffset(inserted.text,table.sourceStart)!;
    final cells=tableRawCells(next),meta=SmartTableMetadata.read(inserted.text,next);
    if(rows) {
      cells[index+1]=[for(final raw in cells[index]) FormulaReferences.shift(raw,1,0)];
    } else {
      for(final row in cells) { row[index+1]=FormulaReferences.shift(row[index],0,1); }
      for(final key in ['formats','calculatedColumns']) {
        final config=meta.section(key);
        if(config.containsKey('$index')) {
          final value=jsonDecode(jsonEncode(config['$index']));
          if(key=='calculatedColumns' && value is Map && value['formula'] is String) value['formula']=FormulaReferences.shift(value['formula'],0,1);
          config['${index+1}']=value; meta.data[key]=config;
        }
      }
    }
    if(hasSummary(old,oldMeta)) _refreshSummary(cells,meta);
    return write(inserted.text,next,cells,meta);
  }

  static TextEditingValue calculatedColumn(String source, MarkdownTable table,int row,int column,{bool reapply=false}) {
    final cells=tableRawCells(table), meta=SmartTableMetadata.read(source,table);
    final formula=cells[row][column];
    if(!meta.editable || row==0 || !formula.startsWith('=')) return TextEditingValue(text:source);
    final end=hasSummary(cells,meta) ? cells.length-1:cells.length;
    if(row>=end) return TextEditingValue(text:source);
    final cols=meta.section('calculatedColumns');
    cols['$column']={'formula':formula,'row':row}; meta.data['calculatedColumns']=cols;
    for(var r=1;r<end;r++) {
      if(reapply || cells[r][column].trim().isEmpty) cells[r][column]=FormulaReferences.shift(formula,r-row,0);
    }
    return write(source,table,cells,meta);
  }

  static TextEditingValue format(String source,MarkdownTable table,int column,Map<String,dynamic> config) {
    final meta=SmartTableMetadata.read(source,table);
    if(!meta.editable) return TextEditingValue(text:source);
    final formats=meta.section('formats'); formats['$column']=config; meta.data['formats']=formats;
    return write(source,table,tableRawCells(table),meta);
  }

  static TextEditingValue paste(String source,MarkdownTable table,TablePosition start,List<List<String>> pasted) {
    if(pasted.isEmpty) return TextEditingValue(text:source);
    final cells=tableRawCells(table), meta=SmartTableMetadata.read(source,table);
    final summary=hasSummary(cells,meta);
    final end=start.row+pasted.length;
    if(end*table.columnCount>FormulaEngine.maxCells) throw const FormulaFailure('#LIMIT!');
    while(cells.length < end+(summary ? 1:0)) {
      final at=summary ? cells.length-1:cells.length;
      cells.insert(at,List.filled(table.columnCount,'')); _fillNewRow(cells,meta,at);
    }
    for(var r=0;r<pasted.length;r++) {
      for(var c=0;c<pasted[r].length && start.column+c<table.columnCount;c++) {
        cells[start.row+r][start.column+c]=pasted[r][c].replaceAll(RegExp(r'[\r\n]'),' ');
      }
    }
    if(summary) _refreshSummary(cells,meta);
    return write(source,table,cells,meta);
  }
}
