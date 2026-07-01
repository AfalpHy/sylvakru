import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/utils/path.dart';

void main() {
  test('convertToRealPathIfNeed ignores Android local file paths', () async {
    final result = await convertToRealPathIfNeed(
      '/storage/emulated/0/TRIM/Download/01.%20test.flac',
    );

    expect(result, isNull);
  });
}
