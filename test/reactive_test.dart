import 'package:test/test.dart';
import 'package:kodi_script/kodi_script.dart';

void main() {
  group('Computed', () {
    test('computes initial value', () async {
      final engine = KSEngine();
      await engine.load('''
        let a = Obs(5)
        let b = Obs(10)
        let sum = Computed(fn() { return a.value + b.value })
        let result = sum.value
      ''');
      
      expect(engine.getVariable('result'), equals(15.0));
    });

    test('recomputes when dependency changes', () async {
      final engine = KSEngine();
      await engine.load('''
        let a = Obs(5)
        let double = Computed(fn() { return a.value * 2 })
        
        let before = double.value
        a.set(7)
        let after = double.value
      ''');
      
      expect(engine.getVariable('before'), equals(10.0));
      expect(engine.getVariable('after'), equals(14.0));
    });

    test('supports nested computed values', () async {
      final engine = KSEngine();
      await engine.load('''
        let base = Obs(10)
        let doubled = Computed(fn() { return base.value * 2 })
        let quadrupled = Computed(fn() { return doubled.value * 2 })
        
        let result = quadrupled.value
      ''');
      
      expect(engine.getVariable('result'), equals(40.0));
    });

    test('caches value until invalidated', () async {
      final engine = KSEngine();
      await engine.load('''
        let callCount = 0
        let a = Obs(5)
        
        let expensive = Computed(fn() {
          callCount = callCount + 1
          return a.value * 2
        })
        
        let r1 = expensive.value
        let r2 = expensive.value
        let r3 = expensive.value
      ''');
      
      // Should only compute once
      expect(engine.getVariable('callCount'), equals(1.0));
    });
    
    test('recomputes after dependency change', () async {
      final engine = KSEngine();
      await engine.load('''
        let callCount = 0
        let a = Obs(5)
        
        let expensive = Computed(fn() {
          callCount = callCount + 1
          return a.value * 2
        })
        
        let r1 = expensive.value  // compute (count=1)
        a.set(10)
        let r2 = expensive.value  // recompute (count=2)
      ''');
      
      expect(engine.getVariable('callCount'), equals(2.0));
      expect(engine.getVariable('r1'), equals(10.0));
      expect(engine.getVariable('r2'), equals(20.0));
    });
  });
  
  group('watch', () {
    test('calls callback when observable changes', () async {
      final engine = KSEngine();
      await engine.load('''
        let a = Obs(5)
        let lastValue = null
        let lastOldValue = null
        
        watch(a, fn(newVal, oldVal) {
          lastValue = newVal
          lastOldValue = oldVal
        })
        
        a.set(10)
      ''');
      
      expect(engine.getVariable('lastValue'), equals(10.0));
      expect(engine.getVariable('lastOldValue'), equals(5.0));
    });
    
    test('tracks multiple changes', () async {
      final engine = KSEngine();
      await engine.load('''
        let a = Obs(0)
        let changeCount = 0
        
        watch(a, fn(newVal, oldVal) {
          changeCount = changeCount + 1
        })
        
        a.set(1)
        a.set(2)
        a.set(3)
      ''');
      
      expect(engine.getVariable('changeCount'), equals(3.0));
    });
    
    test('can watch computed values', () async {
      final engine = KSEngine();
      await engine.load('''
        let base = Obs(5)
        let doubled = Computed(fn() { return base.value * 2 })
        let lastDoubled = null
        
        watch(doubled, fn(newVal) {
          lastDoubled = newVal
        })
        
        base.set(10)
        let currentDoubled = doubled.value
      ''');
      
      expect(engine.getVariable('lastDoubled'), equals(20.0));
      expect(engine.getVariable('currentDoubled'), equals(20.0));
    });
  });
}
