import 'package:kodi_script/kodi_script.dart';

void main() async {
  final engine = KSEngine();
  await engine.load('''
    fn testModal() {
      return Row([
        Expanded(Button("Cancel", { onTap: "close" })),
        SizedBox({ width: 16 }),
        Expanded(Button("Pay", { onTap: "pay" }))
      ])
    }
  ''');
  
  final result = await engine.invoke('testModal');
  print('Result: ${result.value}');
  print('Errors: ${result.errors}');
}
