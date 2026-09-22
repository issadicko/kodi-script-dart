import 'package:kodi_script/kodi_script.dart';
import 'package:test/test.dart';

/// Literals can be laid out one element per line, with a trailing comma, in
/// arrays, objects and call arguments alike.
void main() {
  Object? value(String src) {
    final res = KodiScript.builder(src).execute();
    expect(res.hasErrors, isFalse, reason: 'unexpected errors: ${res.errors}');
    return res.value;
  }

  test('array over several lines with a trailing comma', () {
    expect(value('let t = [\n  1,\n  2,\n  3,\n]\nt[2]'), 3);
    expect(value('let t = [\n]\nt'), isEmpty);
  });

  test('object over several lines with a trailing comma', () {
    expect(value('let o = {\n  "a": 1,\n  "b": 2,\n}\no.a + o.b'), 3);
  });

  test('call arguments over several lines with a trailing comma', () {
    expect(value('let f = fn(a, b) { return a + b; };\nf(\n  1,\n  2,\n)'), 3);
  });

  test('nested literals over several lines', () {
    expect(value('let o = {\n  "a": [\n    1,\n    {"b": 2}\n  ]\n}\no.a[1].b'), 2);
  });

  test('a missing separator is still refused', () {
    expect(KodiScript.builder('let t = [1 2]').execute().hasErrors, isTrue);
  });
}
