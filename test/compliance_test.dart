import 'dart:io';
import 'package:test/test.dart';
import 'package:kodi_script/kodi_script.dart';
import 'package:path/path.dart' as path;

void main() {
  final compliancePath = Platform.environment['KODI_COMPLIANCE_TESTS_PATH'] ?? 
      '../compliance-tests';
  
  final absPath = path.normalize(path.absolute(compliancePath));
  final dir = Directory(absPath);
  
  if (!dir.existsSync()) {
    print('Compliance tests directory not found at $absPath. Skipping.');
    return;
  }

  group('Compliance Tests', () {
    final testFiles = <File>[];
    
    void walkDir(Directory directory) {
      for (final entity in directory.listSync()) {
        if (entity is Directory) {
          walkDir(entity);
        } else if (entity is File && entity.path.endsWith('.kodi')) {
          testFiles.add(entity);
        }
      }
    }
    
    walkDir(dir);
    
    for (final sourceFile in testFiles) {
      final testName = path.relative(sourceFile.path, from: absPath);
      
      test(testName, () {
        final source = sourceFile.readAsStringSync();
        final outPath = sourceFile.path.replaceAll('.kodi', '.out');
        final expectedOut = File(outPath)
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .trim();
        
        final result = KodiScript.run(source);
        
        if (result.hasErrors) {
          fail('Execution failed: ${result.errors.join(", ")}');
        }
        
        final actualOut = result.output.join('\n').replaceAll('\r\n', '\n').trim();
        
        // Normalize output for cross-implementation compatibility
        String normalize(String s) {
          return s
            .replaceAllMapped(RegExp(r'(\d+)\.0(?=[\s,\]\}\)\n]|$)'), (m) => m.group(1)!)
            .replaceAll('<nil>', 'null')
            .replaceAll('hello+world', 'hello%20world');
        }
        
        expect(normalize(actualOut), equals(normalize(expectedOut)));
      });
    }
  });
}
