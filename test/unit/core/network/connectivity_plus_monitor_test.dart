import 'package:ataulfo/core/network/connectivity_plus_monitor.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivityPlusMonitor.isOnlineFrom', () {
    test('none o lista vacía => offline', () {
      expect(
        ConnectivityPlusMonitor.isOnlineFrom(const [ConnectivityResult.none]),
        isFalse,
      );
      expect(
        ConnectivityPlusMonitor.isOnlineFrom(const <ConnectivityResult>[]),
        isFalse,
      );
    });

    test('cualquier enlace real => online', () {
      expect(
        ConnectivityPlusMonitor.isOnlineFrom(const [ConnectivityResult.wifi]),
        isTrue,
      );
      expect(
        ConnectivityPlusMonitor.isOnlineFrom(const [ConnectivityResult.mobile]),
        isTrue,
      );
    });

    test('mezcla con none => online si hay al menos un enlace', () {
      expect(
        ConnectivityPlusMonitor.isOnlineFrom(const [
          ConnectivityResult.none,
          ConnectivityResult.vpn,
        ]),
        isTrue,
      );
    });
  });
}
