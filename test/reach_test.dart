import 'package:reach/reach.dart';
import 'package:test/test.dart';

void main() async {
  group('A group of tests', () {
    test('test', () async {
      final reach = Reach(host: '');
      final response = await reach.rpc('method', ['hi']);
    });
  });
}
