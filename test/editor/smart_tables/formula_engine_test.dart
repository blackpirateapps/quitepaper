import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/domain/smart_tables/formula_engine.dart';

void main() {
  String evaluate(String formula) => FormulaEngine([[formula]]).value(0,0).display;
  test('arithmetic grammar and deterministic decimal rounding', () {
    for (final e in {
      '=2+3*4':'14', '=(2+3)*4':'20', '=-2*-3 + +4':'10',
      '=0.1+0.2':'0.3', '=1/3':'0.333333333333333333',
      '=1/6':'0.166666666666666667', '=sUm(2,AVERAGE(4,6))':'7',
      '=2-3-4':'-5', '=12/2/3':'2', '=1/0':'#DIV/0!',
      '=abc':'#PARSE!', '=2+':'#PARSE!', '=SUM(1,,2)':'#PARSE!',
      '=A0':'#PARSE!', '=A2':'#REF!', '=POW(2,3)':'#PARSE!',
      "'=SUM(A1:A3)":'=SUM(A1:A3)', '=1e3':'#PARSE!',
      '=SUM()':'0', '=COUNT()':'0', '=AVERAGE()':'#DIV/0!',
      '=MIN()':'#VALUE!', '=MAX()':'#VALUE!', '=SUM(#REF!)':'#REF!',
    }.entries) { expect(evaluate(e.key), e.value, reason: e.key); }
    expect(TableDecimal.parse('-1.235').toFixed(2), '-1.24');
    expect(TableDecimal.parse('0.000000000000000001').toString(), '0.000000000000000001');
  });
  test('aggregates skip text/blanks, include zero and formula results', () {
    final engine = FormulaEngine([
      ['Header',''], ['0','=SUM(A1:A5)'], ['2','=COUNT(A1:A5)'],
      ['','=AVERAGE(A1:A5)'], ['text','=MAX(A1:A5)'],
      ['=A3*2','=SUM(B2:B5)'], ['=A5+1','=MIN(A1:A5)'],
    ]);
    expect(engine.value(1,1).display, '2');
    expect(engine.value(2,1).display, '2');
    expect(engine.value(3,1).display, '1');
    expect(engine.value(4,1).display, '2');
    expect(engine.value(5,0).display, '4');
    expect(engine.value(5,1).display, '7');
    expect(engine.value(6,0).display, '#VALUE!');
    expect(engine.value(6,1).display, '0');
  });
  test('cycles, propagated errors and downstream cache invalidation', () {
    final rows = [['2','=A1*3','=SUM(A1:B1)','=C1+1']];
    final engine = FormulaEngine(rows);
    expect(engine.value(0,3).display, '9');
    rows[0][0] = '4'; engine.update(rows);
    expect(engine.value(0,3).display, '17');
    for (final cells in [ ['=A1'], ['=B1','=A1'], ['=SUM(A1:B1)','2'] ]) {
      expect(FormulaEngine([cells]).value(0,0).display, '#CYCLE!');
    }
    engine.update([['=1/0','=A1']]);
    expect(engine.value(0,1).display, '#DIV/0!');
  });
  test('bounds protect parser, recursion, range expansion, magnitude', () {
    expect(evaluate('=${'(' * 70}1${')' * 70}'), '#LIMIT!');
    expect(evaluate('=${'1+' * 1200}1'), '#LIMIT!');
    expect(evaluate('=SUM(A1:ZZ999999)'), '#LIMIT!');
    expect(evaluate('=${'9' * 49}'), '#LIMIT!');
    expect(evaluate('=0.1234567890123456789'), '#LIMIT!');
    final rows = [List.generate(140, (i) => i == 139 ? '1' : '=${CellAddress.columnName(i+1)}1')];
    expect(FormulaEngine(rows).value(0,0).display, '#LIMIT!');
  });
  test('A1 labels, fill anchors, structure and deleted range endpoints', () {
    expect(CellAddress.parse(r'$AA$12').column, 26);
    expect(CellAddress.columnName(701), 'ZZ');
    expect(FormulaReferences.shift(r'=A2*$B$1+C$2+$D3', 2, 1), r'=B4*$B$1+D$2+$D5');
    expect(FormulaReferences.shift('=A1', -1, 0), '=#REF!');
    expect(FormulaReferences.structure(r'=A2+$B$3', rows:true,index:1,delete:false), r'=A3+$B$4');
    expect(FormulaReferences.structure('=SUM(A2:A4)', rows:true,index:1,delete:true), '=SUM(A2:A3)');
    expect(FormulaReferences.structure('=SUM(A2:A2)', rows:true,index:1,delete:true), '=SUM(#REF!)');
    expect(FormulaReferences.structure('=B2+C2', rows:false,index:1,delete:true), '=#REF!+B2');
    expect(FormulaReferences.shift("'=A1",1,1), "'=A1");
  });
}
