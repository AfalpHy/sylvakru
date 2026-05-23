import 'dart:io';
import 'package:sylvakru/base/app.dart';
import 'package:path/path.dart';

final logger = Logger();

class Logger {
  late File _file;

  String _formatForFileName(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');

    return '${t.year}_'
        '${two(t.month)}_'
        '${two(t.day)}_'
        '${two(t.hour)}_'
        '${two(t.minute)}_'
        '${two(t.second)}';
  }

  Future<void> init() async {
    final time = _formatForFileName(DateTime.now());
    if (Platform.isIOS) {
      _file = File('${appDocsDir.path}/logs/$time.txt');
    } else {
      _file = File('${appSupportDir.path}/logs/$time.txt');
    }
    _file.createSync(recursive: true);
    output('App init');
  }

  void output(String msg) {
    final time = DateTime.now().toIso8601String();

    _file.writeAsStringSync(
      '[$time] $msg\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  void export2Directory(String directory) {
    final fileName = basename(_file.path);
    final newPath = join(directory, fileName);
    _file.copySync(newPath);
  }
}
