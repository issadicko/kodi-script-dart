/// KodiScript Native Functions - Built-in functions for the language.
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../reactive/rx.dart';
import '../reactive/rx_list.dart';

/// Native function signature.
typedef NativeFunc = Object? Function(List<Object?>);

/// Registry of native functions for KodiScript.
class NativeFunctions {
  final Map<String, NativeFunc> _functions = {};

  NativeFunctions._();

  /// Shared singleton instance for built-in functions.
  static final shared = NativeFunctions._().._registerBuiltins();

  /// Create a new instance with built-in functions (for custom functions).
  factory NativeFunctions.withBuiltins() {
    final instance = NativeFunctions._();
    instance._functions.addAll(shared._functions);
    return instance;
  }

  NativeFunc? get(String name) => _functions[name];

  void register(String name, NativeFunc fn) {
    _functions[name] = fn;
  }

  void _registerBuiltins() {
    // Reactive factories
    _functions['Obs'] = createObs;
    _functions['List'] = createRxList;

    // String functions
    _functions['toString'] = _nativeToString;
    _functions['toNumber'] = _nativeToNumber;
    _functions['length'] = _nativeLength;
    _functions['substring'] = _nativeSubstring;
    _functions['toUpperCase'] = _nativeToUpperCase;
    _functions['toLowerCase'] = _nativeToLowerCase;
    _functions['trim'] = _nativeTrim;
    _functions['split'] = _nativeSplit;
    _functions['join'] = _nativeJoin;
    _functions['replace'] = _nativeReplace;
    _functions['contains'] = _nativeContains;
    _functions['startsWith'] = _nativeStartsWith;
    _functions['endsWith'] = _nativeEndsWith;
    _functions['indexOf'] = _nativeIndexOf;
    _functions['padLeft'] = _nativePadLeft;
    _functions['padRight'] = _nativePadRight;
    _functions['repeat'] = _nativeRepeat;

    // JSON functions
    _functions['jsonParse'] = _nativeJsonParse;
    _functions['jsonStringify'] = _nativeJsonStringify;

    // Base64 functions
    _functions['base64Encode'] = _nativeBase64Encode;
    _functions['base64Decode'] = _nativeBase64Decode;

    // URL functions
    _functions['urlEncode'] = _nativeUrlEncode;
    _functions['urlDecode'] = _nativeUrlDecode;

    // Type functions
    _functions['typeOf'] = _nativeTypeOf;
    _functions['isNull'] = _nativeIsNull;
    _functions['isNumber'] = _nativeIsNumber;
    _functions['isString'] = _nativeIsString;
    _functions['isBool'] = _nativeIsBool;

    // Math functions
    _functions['abs'] = _nativeAbs;
    _functions['floor'] = _nativeFloor;
    _functions['ceil'] = _nativeCeil;
    _functions['round'] = _nativeRound;
    _functions['min'] = _nativeMin;
    _functions['max'] = _nativeMax;
    _functions['pow'] = _nativePow;
    _functions['sqrt'] = _nativeSqrt;
    _functions['sin'] = _nativeSin;
    _functions['cos'] = _nativeCos;
    _functions['tan'] = _nativeTan;
    _functions['log'] = _nativeLog;
    _functions['log10'] = _nativeLog10;
    _functions['exp'] = _nativeExp;

    // Random functions
    _functions['random'] = _nativeRandom;
    _functions['randomInt'] = _nativeRandomInt;
    _functions['randomUUID'] = _nativeRandomUUID;

    // Crypto/Hash functions
    _functions['md5'] = _nativeMd5;
    _functions['sha1'] = _nativeSha1;
    _functions['sha256'] = _nativeSha256;

    // Array functions
    _functions['sort'] = _nativeSort;
    _functions['reverse'] = _nativeReverse;
    _functions['size'] = _nativeSize;
    _functions['first'] = _nativeFirst;
    _functions['last'] = _nativeLast;
    _functions['slice'] = _nativeSlice;
    _functions['setProperty'] = _nativeSetProperty;

    // Date/Time functions
    _functions['now'] = _nativeNow;
    _functions['date'] = _nativeDate;
    _functions['time'] = _nativeTime;
    _functions['datetime'] = _nativeDatetime;
    _functions['timestamp'] = _nativeTimestamp;
    _functions['formatDate'] = _nativeFormatDate;
    _functions['year'] = _nativeYear;
    _functions['month'] = _nativeMonth;
    _functions['day'] = _nativeDay;
    _functions['hour'] = _nativeHour;
    _functions['minute'] = _nativeMinute;
    _functions['second'] = _nativeSecond;
    _functions['dayOfWeek'] = _nativeDayOfWeek;
    _functions['addDays'] = _nativeAddDays;
    _functions['addHours'] = _nativeAddHours;
    _functions['diffDays'] = _nativeDiffDays;
  }

  // ============ String functions ============

  Object? _nativeToString(List<Object?> args) {
    _requireArgs(args, 1, 'toString');
    return args[0]?.toString() ?? 'null';
  }

  Object? _nativeToNumber(List<Object?> args) {
    _requireArgs(args, 1, 'toNumber');
    final arg = args[0];
    if (arg is double) return arg;
    if (arg is int) return arg.toDouble();
    if (arg is String) {
      return double.tryParse(arg) ??
          (throw ArgumentError("cannot convert '$arg' to number"));
    }
    throw ArgumentError('cannot convert ${arg.runtimeType} to number');
  }

  Object? _nativeLength(List<Object?> args) {
    _requireArgs(args, 1, 'length');
    final arg = args[0];
    if (arg is String) return arg.length.toDouble();
    throw ArgumentError('length requires a string argument');
  }

  Object? _nativeSubstring(List<Object?> args) {
    if (args.length < 2 || args.length > 3) {
      throw ArgumentError('substring requires 2 or 3 arguments');
    }
    final str = args[0] as String;
    final start = (args[1] as double).toInt().clamp(0, str.length);
    if (args.length == 3) {
      final end = (args[2] as double).toInt().clamp(start, str.length);
      return str.substring(start, end);
    }
    return str.substring(start);
  }

  Object? _nativeToUpperCase(List<Object?> args) {
    _requireArgs(args, 1, 'toUpperCase');
    return (args[0] as String).toUpperCase();
  }

  Object? _nativeToLowerCase(List<Object?> args) {
    _requireArgs(args, 1, 'toLowerCase');
    return (args[0] as String).toLowerCase();
  }

  Object? _nativeTrim(List<Object?> args) {
    _requireArgs(args, 1, 'trim');
    return (args[0] as String).trim();
  }

  Object? _nativeSplit(List<Object?> args) {
    _requireArgs(args, 2, 'split');
    return (args[0] as String).split(args[1] as String);
  }

  Object? _nativeJoin(List<Object?> args) {
    _requireArgs(args, 2, 'join');
    final arr = args[0] as List;
    return arr.map((e) => e?.toString() ?? 'null').join(args[1] as String);
  }

  Object? _nativeReplace(List<Object?> args) {
    _requireArgs(args, 3, 'replace');
    return (args[0] as String).replaceAll(args[1] as String, args[2] as String);
  }

  Object? _nativeContains(List<Object?> args) {
    _requireArgs(args, 2, 'contains');
    return (args[0] as String).contains(args[1] as String);
  }

  Object? _nativeStartsWith(List<Object?> args) {
    _requireArgs(args, 2, 'startsWith');
    return (args[0] as String).startsWith(args[1] as String);
  }

  Object? _nativeEndsWith(List<Object?> args) {
    _requireArgs(args, 2, 'endsWith');
    return (args[0] as String).endsWith(args[1] as String);
  }

  Object? _nativeIndexOf(List<Object?> args) {
    _requireArgs(args, 2, 'indexOf');
    return (args[0] as String).indexOf(args[1] as String).toDouble();
  }

  Object? _nativePadLeft(List<Object?> args) {
    if (args.length < 2) throw Exception('padLeft requires at least 2 arguments');
    final str = args[0]?.toString() ?? '';
    final length = (args[1] as num).toInt();
    final padChar = args.length > 2 ? (args[2]?.toString() ?? ' ').substring(0, 1) : ' ';
    return str.padLeft(length, padChar);
  }

  Object? _nativePadRight(List<Object?> args) {
    if (args.length < 2) throw Exception('padRight requires at least 2 arguments');
    final str = args[0]?.toString() ?? '';
    final length = (args[1] as num).toInt();
    final padChar = args.length > 2 ? (args[2]?.toString() ?? ' ').substring(0, 1) : ' ';
    return str.padRight(length, padChar);
  }

  Object? _nativeRepeat(List<Object?> args) {
    _requireArgs(args, 2, 'repeat');
    final str = args[0]?.toString() ?? '';
    final count = (args[1] as num).toInt().clamp(0, 1000000);
    return str * count;
  }

  // ============ JSON functions ============

  Object? _nativeJsonParse(List<Object?> args) {
    _requireArgs(args, 1, 'jsonParse');
    return jsonDecode(args[0] as String);
  }

  Object? _nativeJsonStringify(List<Object?> args) {
    _requireArgs(args, 1, 'jsonStringify');
    return jsonEncode(args[0]);
  }

  // ============ Base64 functions ============

  Object? _nativeBase64Encode(List<Object?> args) {
    _requireArgs(args, 1, 'base64Encode');
    return base64Encode(utf8.encode(args[0] as String));
  }

  Object? _nativeBase64Decode(List<Object?> args) {
    _requireArgs(args, 1, 'base64Decode');
    return utf8.decode(base64Decode(args[0] as String));
  }

  // ============ URL functions ============

  Object? _nativeUrlEncode(List<Object?> args) {
    _requireArgs(args, 1, 'urlEncode');
    return Uri.encodeComponent(args[0] as String);
  }

  Object? _nativeUrlDecode(List<Object?> args) {
    _requireArgs(args, 1, 'urlDecode');
    return Uri.decodeComponent(args[0] as String);
  }

  // ============ Type functions ============

  Object? _nativeTypeOf(List<Object?> args) {
    _requireArgs(args, 1, 'typeOf');
    final arg = args[0];
    if (arg == null) return 'null';
    if (arg is String) return 'string';
    if (arg is double || arg is int) return 'number';
    if (arg is bool) return 'boolean';
    if (arg is Map) return 'object';
    if (arg is List) return 'array';
    return 'unknown';
  }

  Object? _nativeIsNull(List<Object?> args) {
    _requireArgs(args, 1, 'isNull');
    return args[0] == null;
  }

  Object? _nativeIsNumber(List<Object?> args) {
    _requireArgs(args, 1, 'isNumber');
    return args[0] is double || args[0] is int;
  }

  Object? _nativeIsString(List<Object?> args) {
    _requireArgs(args, 1, 'isString');
    return args[0] is String;
  }

  Object? _nativeIsBool(List<Object?> args) {
    _requireArgs(args, 1, 'isBool');
    return args[0] is bool;
  }

  // ============ Math functions ============

  Object? _nativeAbs(List<Object?> args) {
    _requireArgs(args, 1, 'abs');
    return _toDouble(args[0]).abs();
  }

  Object? _nativeFloor(List<Object?> args) {
    _requireArgs(args, 1, 'floor');
    return _toDouble(args[0]).floorToDouble();
  }

  Object? _nativeCeil(List<Object?> args) {
    _requireArgs(args, 1, 'ceil');
    return _toDouble(args[0]).ceilToDouble();
  }

  Object? _nativeRound(List<Object?> args) {
    _requireArgs(args, 1, 'round');
    return _toDouble(args[0]).roundToDouble();
  }

  Object? _nativeMin(List<Object?> args) {
    if (args.length < 2) throw ArgumentError('min requires at least 2 arguments');
    return args.map(_toDouble).reduce(min);
  }

  Object? _nativeMax(List<Object?> args) {
    if (args.length < 2) throw ArgumentError('max requires at least 2 arguments');
    return args.map(_toDouble).reduce(max);
  }

  Object? _nativePow(List<Object?> args) {
    _requireArgs(args, 2, 'pow');
    return pow(_toDouble(args[0]), _toDouble(args[1])).toDouble();
  }

  Object? _nativeSqrt(List<Object?> args) {
    _requireArgs(args, 1, 'sqrt');
    final n = _toDouble(args[0]);
    if (n < 0) throw ArgumentError('sqrt of negative number');
    return sqrt(n);
  }

  Object? _nativeSin(List<Object?> args) {
    _requireArgs(args, 1, 'sin');
    return sin(_toDouble(args[0]));
  }

  Object? _nativeCos(List<Object?> args) {
    _requireArgs(args, 1, 'cos');
    return cos(_toDouble(args[0]));
  }

  Object? _nativeTan(List<Object?> args) {
    _requireArgs(args, 1, 'tan');
    return tan(_toDouble(args[0]));
  }

  Object? _nativeLog(List<Object?> args) {
    _requireArgs(args, 1, 'log');
    final n = _toDouble(args[0]);
    if (n <= 0) throw ArgumentError('log of non-positive number');
    return log(n);
  }

  Object? _nativeLog10(List<Object?> args) {
    _requireArgs(args, 1, 'log10');
    final n = _toDouble(args[0]);
    if (n <= 0) throw ArgumentError('log10 of non-positive number');
    return log(n) / ln10;
  }

  Object? _nativeExp(List<Object?> args) {
    _requireArgs(args, 1, 'exp');
    return exp(_toDouble(args[0]));
  }

  // ============ Random functions ============

  static final _random = Random();

  Object? _nativeRandom(List<Object?> args) {
    if (args.isNotEmpty) throw ArgumentError('random takes no arguments');
    return _random.nextDouble();
  }

  Object? _nativeRandomInt(List<Object?> args) {
    _requireArgs(args, 2, 'randomInt');
    final minVal = _toDouble(args[0]).toInt();
    final maxVal = _toDouble(args[1]).toInt();
    if (minVal >= maxVal) throw ArgumentError('randomInt: min must be less than max');
    return (_random.nextInt(maxVal - minVal + 1) + minVal).toDouble();
  }

  Object? _nativeRandomUUID(List<Object?> args) {
    if (args.isNotEmpty) throw ArgumentError('randomUUID takes no arguments');
    // Generate UUID v4
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  // ============ Crypto/Hash functions ============

  Object? _nativeMd5(List<Object?> args) {
    _requireArgs(args, 1, 'md5');
    return md5.convert(utf8.encode(args[0] as String)).toString();
  }

  Object? _nativeSha1(List<Object?> args) {
    _requireArgs(args, 1, 'sha1');
    return sha1.convert(utf8.encode(args[0] as String)).toString();
  }

  Object? _nativeSha256(List<Object?> args) {
    _requireArgs(args, 1, 'sha256');
    return sha256.convert(utf8.encode(args[0] as String)).toString();
  }

  // ============ Array functions ============

  Object? _nativeSort(List<Object?> args) {
    if (args.isEmpty || args.length > 2) {
      throw ArgumentError('sort requires 1 or 2 arguments');
    }
    final arr = List.of(args[0] as List);
    final ascending = args.length < 2 || (args[1] as String) != 'desc';
    arr.sort((a, b) {
      final cmp = _compareValues(a, b);
      return ascending ? cmp : -cmp;
    });
    return arr;
  }

  Object? _nativeReverse(List<Object?> args) {
    _requireArgs(args, 1, 'reverse');
    return (args[0] as List).reversed.toList();
  }

  Object? _nativeSize(List<Object?> args) {
    _requireArgs(args, 1, 'size');
    final v = args[0];
    if (v is List) return v.length.toDouble();
    if (v is String) return v.length.toDouble();
    if (v is Map) return v.length.toDouble();
    throw ArgumentError('size requires an array, string, or object');
  }

  Object? _nativeFirst(List<Object?> args) {
    _requireArgs(args, 1, 'first');
    final arr = args[0] as List;
    return arr.isEmpty ? null : arr.first;
  }

  Object? _nativeLast(List<Object?> args) {
    _requireArgs(args, 1, 'last');
    final arr = args[0] as List;
    return arr.isEmpty ? null : arr.last;
  }

  Object? _nativeSlice(List<Object?> args) {
    if (args.length < 2 || args.length > 3) {
      throw ArgumentError('slice requires 2 or 3 arguments');
    }
    final arr = args[0] as List;
    final start = _toDouble(args[1]).toInt().clamp(0, arr.length);
    if (args.length == 3) {
      final end = _toDouble(args[2]).toInt().clamp(start, arr.length);
      return arr.sublist(start, end);
    }
    return arr.sublist(start);
  }

  Object? _nativeSetProperty(List<Object?> args) {
    _requireArgs(args, 3, 'setProperty');
    final target = args[0];
    final key = args[1];
    final value = args[2];

    if (target is Map) {
      target[key] = value;
      return value;
    } else if (target is List) {
      final index = _toDouble(key).toInt();
      if (index >= 0 && index < target.length) {
        target[index] = value;
        return value;
      }
      throw RangeError('Index out of range: $index');
    }
    throw ArgumentError('setProperty requires a map or array as target');
  }

  // ============ Helpers ============

  static void _requireArgs(List<Object?> args, int count, String name) {
    if (args.length != count) {
      throw ArgumentError('$name requires $count argument(s)');
    }
  }

  static double _toDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _compareValues(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    final aNum = _toDoubleOrNull(a);
    final bNum = _toDoubleOrNull(b);

    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }

    return a.toString().compareTo(b.toString());
  }

  static double? _toDoubleOrNull(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }

  // ============ Date/Time functions ============

  Object? _nativeNow(List<Object?> args) {
    if (args.isNotEmpty) throw ArgumentError('now takes no arguments');
    return DateTime.now().millisecondsSinceEpoch.toDouble();
  }

  Object? _nativeDate(List<Object?> args) {
    if (args.isNotEmpty) throw ArgumentError('date takes no arguments');
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Object? _nativeTime(List<Object?> args) {
    if (args.isNotEmpty) throw ArgumentError('time takes no arguments');
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Object? _nativeDatetime(List<Object?> args) {
    if (args.isNotEmpty) throw ArgumentError('datetime takes no arguments');
    return DateTime.now().toIso8601String();
  }

  Object? _nativeTimestamp(List<Object?> args) {
    if (args.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toDouble();
    }
    final dateStr = args[0] as String;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) {
      throw ArgumentError('cannot parse date: $dateStr');
    }
    return parsed.millisecondsSinceEpoch.toDouble();
  }

  Object? _nativeFormatDate(List<Object?> args) {
    if (args.isEmpty || args.length > 2) {
      throw ArgumentError('formatDate requires 1 or 2 arguments');
    }
    final ts = _toDouble(args[0]).toInt();
    final format = args.length == 2 ? args[1] as String : 'YYYY-MM-DD';
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    
    var result = format;
    result = result.replaceAll('YYYY', date.year.toString().padLeft(4, '0'));
    result = result.replaceAll('MM', date.month.toString().padLeft(2, '0'));
    result = result.replaceAll('DD', date.day.toString().padLeft(2, '0'));
    result = result.replaceAll('HH', date.hour.toString().padLeft(2, '0'));
    result = result.replaceAll('mm', date.minute.toString().padLeft(2, '0'));
    result = result.replaceAll('ss', date.second.toString().padLeft(2, '0'));
    return result;
  }

  Object? _nativeYear(List<Object?> args) {
    final ts = args.isEmpty ? DateTime.now().millisecondsSinceEpoch : _toDouble(args[0]).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ts).year.toDouble();
  }

  Object? _nativeMonth(List<Object?> args) {
    final ts = args.isEmpty ? DateTime.now().millisecondsSinceEpoch : _toDouble(args[0]).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ts).month.toDouble();
  }

  Object? _nativeDay(List<Object?> args) {
    final ts = args.isEmpty ? DateTime.now().millisecondsSinceEpoch : _toDouble(args[0]).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ts).day.toDouble();
  }

  Object? _nativeHour(List<Object?> args) {
    final ts = args.isEmpty ? DateTime.now().millisecondsSinceEpoch : _toDouble(args[0]).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ts).hour.toDouble();
  }

  Object? _nativeMinute(List<Object?> args) {
    final ts = args.isEmpty ? DateTime.now().millisecondsSinceEpoch : _toDouble(args[0]).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ts).minute.toDouble();
  }

  Object? _nativeSecond(List<Object?> args) {
    final ts = args.isEmpty ? DateTime.now().millisecondsSinceEpoch : _toDouble(args[0]).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ts).second.toDouble();
  }

  Object? _nativeDayOfWeek(List<Object?> args) {
    final ts = args.isEmpty ? DateTime.now().millisecondsSinceEpoch : _toDouble(args[0]).toInt();
    // Dart: weekday is 1=Monday, 7=Sunday. We want 0=Sunday.
    final weekday = DateTime.fromMillisecondsSinceEpoch(ts).weekday;
    return (weekday == 7 ? 0 : weekday).toDouble();
  }

  Object? _nativeAddDays(List<Object?> args) {
    _requireArgs(args, 2, 'addDays');
    final ts = _toDouble(args[0]).toInt();
    final days = _toDouble(args[1]).toInt();
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return date.add(Duration(days: days)).millisecondsSinceEpoch.toDouble();
  }

  Object? _nativeAddHours(List<Object?> args) {
    _requireArgs(args, 2, 'addHours');
    final ts = _toDouble(args[0]).toInt();
    final hours = _toDouble(args[1]).toInt();
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    return date.add(Duration(hours: hours)).millisecondsSinceEpoch.toDouble();
  }

  Object? _nativeDiffDays(List<Object?> args) {
    _requireArgs(args, 2, 'diffDays');
    final ts1 = _toDouble(args[0]).toInt();
    final ts2 = _toDouble(args[1]).toInt();
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d2.difference(d1).inDays.toDouble();
  }
}
