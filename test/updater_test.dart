import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/updater.dart';
import 'package:gluckspfennig/core/version.dart';

void main() {
  test('Versionen vergleichen', () {
    expect(isNewer('0.9.40', '0.9.39+34'), isTrue);
    expect(isNewer('v0.10.0', '0.9.99'), isTrue);
    expect(isNewer('0.9.39', '0.9.39+34'), isFalse);
    expect(isNewer('0.9.38', '0.9.39'), isFalse);
    expect(isNewer('1.0.0', appVersion), isTrue);
  });

  test('Antwort von GitHub lesen', () {
    final r = parseRelease({
      'tag_name': 'v0.9.40',
      'html_url': 'https://github.com/Batlh/casino-app/releases/tag/v0.9.40',
      'body': 'Änderungen:\n- Eins\n- Zwei',
      'assets': [
        {'name': 'gluckspfennig-0.9.40-linux.tar.gz', 'browser_download_url': 'https://x/l'},
        {'name': 'gluckspfennig-0.9.40.apk', 'browser_download_url': 'https://x/a'},
        {'name': 'gluckspfennig-0.9.40-windows.zip', 'browser_download_url': 'https://x/w'},
      ],
    })!;
    expect(r.version, '0.9.40');
    expect(r.apk, 'https://x/a');
    expect(r.windowsZip, 'https://x/w');
    // Der Vorab-Stand „latest“ ist keine Version
    expect(parseRelease({'tag_name': 'latest'}), isNull);
  });
}
