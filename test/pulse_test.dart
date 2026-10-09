import 'package:flutter_test/flutter_test.dart';
import 'package:smartcook/core/services/pulse.dart';

void main() {
  test('the next reading follows the server, within sane limits', () {
    expect(Pulse.nextDelay({'next': 60, 'watch': false}), 60);
    expect(Pulse.nextDelay({'next': 2, 'watch': true}), 2);
    expect(Pulse.nextDelay({'next': 0, 'watch': true}), Pulse.minSeconds,
        reason: 'never faster than the floor');
    expect(Pulse.nextDelay({'next': 99999}), Pulse.maxSeconds);
  });

  test('anything unreadable falls back to once a minute', () {
    for (final bad in [
      null,
      'x',
      5,
      <String, dynamic>{},
      {'next': 'soon'}
    ]) {
      expect(Pulse.nextDelay(bad), Pulse.slow, reason: '$bad');
    }
  });

  test(
      'a low battery that is not charging slows the pace, unless somebody is watching',
      () {
    expect(Pulse.nextDelay({'next': 60}, battery: 10, charging: false), 180);
    expect(Pulse.nextDelay({'next': 60}, battery: 10, charging: true), 60);
    expect(Pulse.nextDelay({'next': 60}, battery: 80), 60);
    expect(
        Pulse.nextDelay({'next': 2, 'watch': true},
            battery: 5, charging: false),
        2,
        reason: 'a watcher asked for it, so it is honoured');
  });
}
