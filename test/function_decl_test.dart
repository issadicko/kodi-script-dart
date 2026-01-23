import 'package:test/test.dart';
import 'package:kodi_script/kodi_script.dart';

void main() {
  test('Function declaration syntax works', () async {
    final engine = KSEngine();
    await engine.load('''
      fn add(a, b) {
        return a + b
      }
      
      let result = add(5, 3)
    ''');
    
    expect(engine.getVariable('result'), equals(8.0));
  });

  test('Recursive function declaration works', () async {
    final engine = KSEngine();
    await engine.load('''
      fn fib(n) {
        if (n <= 1) { return n }
        return fib(n - 1) + fib(n - 2)
      }
      
      let result = fib(10)
    ''');
    
    expect(engine.getVariable('result'), equals(55.0));
  });
  
  test('Function declaration alongside closure works', () async {
    final engine = KSEngine();
    await engine.load('''
      fn multiply(a, b) {
        return a * b
      }
      
      let double = fn(x) { return multiply(x, 2) }
      
      let result = double(5)
    ''');
    
    expect(engine.getVariable('result'), equals(10.0));
  });
  
  test('Nested function declarations work', () async {
    final engine = KSEngine();
    await engine.load('''
      fn outer(x) {
        fn inner(y) {
          return x + y
        }
        return inner(10)
      }
      
      let result = outer(5)
    ''');
    
    expect(engine.getVariable('result'), equals(15.0));
  });
}
