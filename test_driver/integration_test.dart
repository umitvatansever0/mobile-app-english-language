import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// integration_test ekran görüntülerini screenshots/ klasörüne yazar.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final f = await File('screenshots/$name.png').create(recursive: true);
      f.writeAsBytesSync(bytes);
      return true;
    },
  );
}
