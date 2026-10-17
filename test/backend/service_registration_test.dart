import 'package:flutter_test/flutter_test.dart';
import 'package:yukari/backend/privilege_windows.dart';
import 'package:yukari/backend/system/systemd_service.dart';

void main() {
  test('systemd unit quotes and escapes the command line', () {
    final unit = SystemdService.unit('/opt/Yukari App/bin/yukari-service', [
      'run',
      '--data-dir',
      r'/home/u/100%"$x\y',
    ]);
    expect(
      unit,
      contains(
        r'ExecStart="/opt/Yukari App/bin/yukari-service" "run" "--data-dir" '
        r'"/home/u/100%%\"$$x\\y"',
      ),
    );
    expect(unit, contains('RuntimeDirectory=yukari'));
    expect(unit, contains('WantedBy=multi-user.target'));
  });

  test('Unix registers the app executable where it lies', () async {
    expect(
      await SystemdService().prepare('/opt/yukari/bin/yukari-service'),
      '/opt/yukari/bin/yukari-service',
    );
  });

  test('Windows arguments survive CommandLineToArgvW', () {
    expect(quoteArgument('run'), 'run');
    expect(quoteArgument(''), '""');
    expect(quoteArgument(r'C:\Users\A B\AppData'), r'"C:\Users\A B\AppData"');
    expect(quoteArgument(r'C:\dir with space\'), r'"C:\dir with space\\"');
    expect(quoteArgument(r'say "hi"'), r'"say \"hi\""');
    expect(quoteArgument(r'a\"b'), r'"a\\\"b"');
  });
}
