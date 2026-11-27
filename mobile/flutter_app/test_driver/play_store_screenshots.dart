import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(Platform.environment['SANQI_SCREENSHOT_OUTPUT']!);
  final captured = <String>{};
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-z]{2}(?:-[A-Z]{2})?/0[1-4]-[a-z-]+$').hasMatch(name) ||
          bytes.isEmpty ||
          !captured.add(name)) {
        return false;
      }
      final file = File('${output.path}/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      stdout.writeln(file.path);
      return true;
    },
    responseDataCallback: (_) {
      if (captured.length != 56) {
        throw StateError('Expected 56 screenshots, got ${captured.length}.');
      }
    },
  );
}
