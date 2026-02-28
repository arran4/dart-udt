import 'package:dart_udt/dart_udt.dart';
import 'package:test/test.dart';

void main() {
  test('status reports scaffold state', () {
    const scaffold = UdtPortScaffold();
    expect(scaffold.status(), contains('scaffold'));
  });
}
