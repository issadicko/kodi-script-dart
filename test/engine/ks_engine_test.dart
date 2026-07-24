import 'package:kodi_script/kodi_script.dart';
import 'package:test/test.dart';

void main() {
  group('KSEngine', () {
    late KSEngine engine;

    setUp(() {
      engine = KSEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    group('load()', () {
      test('should load a simple script successfully', () async {
        final result = await engine.load('''
          let x = 10
          let y = 20
        ''');

        expect(result.success, isTrue);
        expect(result.hasErrors, isFalse);
        expect(engine.isLoaded, isTrue);
      });

      test('should return errors for invalid syntax', () async {
        final result = await engine.load('''
          let x = 
        ''');

        expect(result.success, isFalse);
        expect(result.hasErrors, isTrue);
        expect(engine.isLoaded, isFalse);
      });

      test('should initialize variables during load', () async {
        await engine.load('''
          let counter = 0
          let name = "test"
        ''');

        expect(engine.getVariable('counter'), equals(0.0));
        expect(engine.getVariable('name'), equals('test'));
      });

      test('should register functions during load', () async {
        await engine.load('''
          let add = fn(a, b) {
            return a + b
          }
        ''');

        expect(engine.isLoaded, isTrue);
        final fn = engine.getVariable('add');
        expect(fn, isA<FunctionValue>());
      });
    });

    group('invoke()', () {
      test('should invoke a function and return result', () async {
        await engine.load('''
          let greet = fn(name) {
            return "Hello, " + name
          }
        ''');

        final result = await engine.invoke('greet', ['World']);

        expect(result.success, isTrue);
        expect(result.value, equals('Hello, World'));
      });

      test('should preserve state between invocations', () async {
        await engine.load('''
          let counter = 0
          
          let increment = fn() {
            counter = counter + 1
            return counter
          }
        ''');

        final result1 = await engine.invoke('increment');
        final result2 = await engine.invoke('increment');
        final result3 = await engine.invoke('increment');

        expect(result1.value, equals(1.0));
        expect(result2.value, equals(2.0));
        expect(result3.value, equals(3.0));
      });

      test('should return error if function not found', () async {
        await engine.load('let x = 1');

        final result = await engine.invoke('nonExistent');

        expect(result.success, isFalse);
        expect(result.errors.first, contains('not found'));
      });

      test('should return error if engine not loaded', () async {
        final result = await engine.invoke('test');

        expect(result.success, isFalse);
        expect(result.errors.first, contains('not loaded'));
      });

      test('should return error if invoking a non-function', () async {
        await engine.load('let x = 42');

        final result = await engine.invoke('x');

        expect(result.success, isFalse);
        expect(result.errors.first, contains('not a function'));
      });
      test('should allow function calls with missing arguments', () async {
        await engine.load('''
          let testFn = fn(a, b) {
             let res = "a=" + a
             if (b == null) {
                res = res + ", b=null"
             } else {
                res = res + ", b=" + b
             }
             return res
          }
        ''');

        final result = await engine.invoke('testFn', ['val']); // Pass 1 arg, expect b=null
        
        if (!result.success) {
           fail('Invoke failed: ${result.errors}');
        }
        expect(result.value, equals('a=val, b=null'));
      });
    });

    group('invokeSync()', () {
      test('should invoke synchronously and return result', () async {
        await engine.load('''
          let double = fn(x) {
            return x * 2
          }
        ''');

        final result = engine.invokeSync('double', [5.0]);

        expect(result, equals(10.0));
      });

      test('should throw if engine not loaded', () {
        expect(() => engine.invokeSync('test'), throwsStateError);
      });

      test('should throw if function not found', () async {
        await engine.load('let x = 1');

        expect(() => engine.invokeSync('missing'), throwsArgumentError);
      });
    });

    group('getVariable() / setVariable()', () {
      test('should get variable value', () async {
        await engine.load('let x = 42');

        expect(engine.getVariable('x'), equals(42.0));
      });

      test('should return null for undefined variable', () async {
        await engine.load('let x = 1');

        expect(engine.getVariable('undefined'), isNull);
      });

      test('should set variable value', () async {
        await engine.load('let x = 0');

        engine.setVariable('x', 100);

        expect(engine.getVariable('x'), equals(100));
      });

      test('should allow injecting new variables', () async {
        await engine.load('''
          let useInjected = fn() {
            return injected * 2
          }
        ''');

        engine.setVariable('injected', 21.0);
        final result = await engine.invoke('useInjected');

        expect(result.value, equals(42.0));
      });
    });

    group('getState()', () {
      test('should return all variables as a map', () async {
        await engine.load('''
          let a = 1
          let b = "two"
          let c = true
        ''');

        final state = engine.getState();

        expect(state['a'], equals(1.0));
        expect(state['b'], equals('two'));
        expect(state['c'], equals(true));
      });
    });

    group('reset()', () {
      test('should reset engine to initial state', () async {
        await engine.load('let x = 100');
        expect(engine.isLoaded, isTrue);

        engine.reset();

        expect(engine.isLoaded, isFalse);
        expect(engine.getVariable('x'), isNull);
      });

      test('should allow reloading after reset', () async {
        await engine.load('let x = 1');
        engine.reset();

        final result = await engine.load('let y = 2');

        expect(result.success, isTrue);
        expect(engine.getVariable('y'), equals(2.0));
        expect(engine.getVariable('x'), isNull);
      });
    });

    group('output handling', () {
      test('should capture print output', () async {
        await engine.load('''
          print("Hello")
          print("World")
        ''');

        expect(engine.getOutput(), contains('Hello'));
        expect(engine.getOutput(), contains('World'));
      });

      test('should clear output on clearOutput()', () async {
        await engine.load('print("test")');
        expect(engine.getOutput(), isNotEmpty);

        engine.clearOutput();

        expect(engine.getOutput(), isEmpty);
      });
    });
  });

  group('Reactive Variables (Rx)', () {
    late KSEngine engine;

    setUp(() {
      engine = KSEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('should create Rx with Obs() function', () async {
      await engine.load('let counter = Obs(0)');

      final counter = engine.getVariable('counter');
      expect(counter, isA<Rx>());
    });

    test('should get Rx value via .value property', () async {
      await engine.load('''
        let counter = Obs(42)
        
        let getValue = fn() {
          return counter.value
        }
      ''');

      final result = await engine.invoke('getValue');

      expect(result.value, equals(42));
    });

    test('should set Rx value via .set() method', () async {
      await engine.load('''
        let counter = Obs(0)
        
        let increment = fn() {
          counter.set(counter.value + 1)
          return counter.value
        }
      ''');

      final result1 = await engine.invoke('increment');
      final result2 = await engine.invoke('increment');

      expect(result1.value, equals(1));
      expect(result2.value, equals(2));
    });

    test('Rx should notify listeners on value change', () async {
      await engine.load('let counter = Obs(0)');

      final rx = engine.getVariable('counter') as Rx;
      var notified = false;
      rx.addListener(() => notified = true);

      rx.value = 1;

      expect(notified, isTrue);
    });

    test('Rx should not notify if value unchanged', () async {
      await engine.load('let counter = Obs(5)');

      final rx = engine.getVariable('counter') as Rx;
      var notifyCount = 0;
      rx.addListener(() => notifyCount++);

      rx.value = 5; // Same value
      rx.value = 5;

      expect(notifyCount, equals(0));
    });

    test('should toggle boolean Rx', () async {
      await engine.load('''
        let flag = Obs(false)
        
        let toggle = fn() {
          flag.toggle()
          return flag.value
        }
      ''');

      final result1 = await engine.invoke('toggle');
      final result2 = await engine.invoke('toggle');

      expect(result1.value, equals(true));
      expect(result2.value, equals(false));
    });
  });

  group('RxNotifier', () {
    test('should capture dependencies during capture phase', () {
      final notifier = RxNotifier.instance;
      final rx1 = Rx(1);
      final rx2 = Rx(2);

      notifier.startCapture();

      // Access values to register dependencies
      final _ = rx1.value;
      final __ = rx2.value;

      final captured = notifier.stopCapture();

      expect(captured, contains(rx1));
      expect(captured, contains(rx2));
    });

    test('should not capture when not in capture mode', () {
      final notifier = RxNotifier.instance;
      final rx = Rx(0);

      // Access without startCapture
      final _ = rx.value;

      expect(notifier.isCapturing, isFalse);
    });

    test('should clear capture state on cancelCapture()', () {
      final notifier = RxNotifier.instance;

      notifier.startCapture();
      expect(notifier.isCapturing, isTrue);

      notifier.cancelCapture();

      expect(notifier.isCapturing, isFalse);
    });
  });

  group('Mini-App Screen Building', () {
    late KSEngine engine;

    setUp(() {
      engine = KSEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('should return JSON structure from build()', () async {
      // Note: KodiScript requires objects/arrays on single lines
      await engine.load('''
        let build = fn() {
          return { type: "Column", children: [ { type: "Text", props: { content: "Hello" } } ] }
        }
      ''');

      final result = await engine.invoke('build');

      expect(result.success, isTrue);
      final ui = result.value as Map<String, dynamic>;
      expect(ui['type'], equals('Column'));
      expect(ui['children'], isA<List>());
    });

    test('should support reactive counter example', () async {
      await engine.load('''
        let counter = Obs(0)
        
        let increment = fn() {
          counter.set(counter.value + 1)
        }
        
        let build = fn() {
          return { type: "Column", children: [ { type: "Text", props: { content: "Counter: " + counter.value } }, { type: "Button", props: { label: "+", onTap: "increment" } } ] }
        }
      ''');

      // Initial build
      var buildResult = await engine.invoke('build');
      var ui = buildResult.value as Map<String, dynamic>;
      var children = ui['children'] as List;
      var textWidget = children[0] as Map<String, dynamic>;
      // Canonical formatting renders whole numbers without a trailing ".0".
      expect(textWidget['props']['content'], equals('Counter: 0'));

      // Increment
      await engine.invoke('increment');

      // Rebuild
      buildResult = await engine.invoke('build');
      ui = buildResult.value as Map<String, dynamic>;
      children = ui['children'] as List;
      textWidget = children[0] as Map<String, dynamic>;
      expect(textWidget['props']['content'], equals('Counter: 1'));
    });

    test('should support Obx-style partial rebuilds', () async {
      await engine.load('''
        let counter = Obs(0)
        
        let increment = fn() {
          counter.set(counter.value + 1)
        }
        
        let buildCounter = fn() {
          return { type: "Text", props: { content: counter.value } }
        }
        
        let build = fn() {
          return { type: "Column", children: [ { type: "Text", props: { content: "Static Title" } }, { type: "Obx", builder: "buildCounter" }, { type: "Button", props: { label: "+", onTap: "increment" } } ] }
        }
      ''');

      // Simulate Obx behavior - only rebuild the counter portion
      await engine.invoke('increment');
      await engine.invoke('increment');

      final counterResult = await engine.invoke('buildCounter');
      final counterWidget = counterResult.value as Map<String, dynamic>;

      expect(counterWidget['props']['content'], equals(2));
    });
  });
}
