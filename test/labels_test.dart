import 'package:flutter_test/flutter_test.dart';
import 'package:tm_classifier/services/labels.dart';

void main() {
  test('normal labels file', () {
    expect(parseLabels('0 Mug\n1 Bottle\n'), ['Mug', 'Bottle']);
  });

  test('Windows line endings, trailing blank line, label with a space', () {
    expect(parseLabels('0 Mug\r\n1 Bottle\r\n2 Car keys\r\n\r\n'), [
      'Mug',
      'Bottle',
      'Car keys',
    ]);
  });

  test('our own labels.txt (six classes, in file order)', () {
    expect(
      parseLabels('0 me\n1 nothing\n2 phone\n3 bokal\n4 mouse\n5 notebook\n'),
      ['me', 'nothing', 'phone', 'bokal', 'mouse', 'notebook'],
    );
  });

  test('a label that starts with a digit keeps it', () {
    expect(parseLabels('0 3D pen\n1 2 cups'), ['3D pen', '2 cups']);
  });

  test('empty file gives no labels', () {
    expect(parseLabels(''), isEmpty);
    expect(parseLabels('\n\r\n  \n'), isEmpty);
  });
}
