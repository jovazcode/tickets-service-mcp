// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:test/test.dart';
import 'package:tickets_service_mcp/tickets_service_mcp.dart';

void main() {
  group('TicketsServiceMcp', () {
    test('can be instantiated', () {
      expect(TicketsServiceMcp(), isNotNull);
    });
  });
}
