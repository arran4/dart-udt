import 'package:dart_udt/src/udt_port/queue/queue_structures.dart';

void main() {
  final list = UdtReceiveUserList<int>();
  for (var i = 0; i < 1000; i++) {
    list.insert(socketId: i, value: i, timestampMicros: 0);
  }

  final stopwatch = Stopwatch()..start();
  int sum = 0;
  for (var i = 0; i < 10000; i++) {
    final order = list.socketOrder;
    sum += order.length;
  }
  stopwatch.stop();

  print('socketOrder took: ${stopwatch.elapsedMicroseconds} us');
  print('Sum: $sum');
}
