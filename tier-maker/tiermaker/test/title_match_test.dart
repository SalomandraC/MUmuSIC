import 'package:flutter_test/flutter_test.dart';
import 'package:mumusic/core/audio/title_match.dart';

void main() {
  test('matches spoken numbers, prefers exact title and rejects ambiguity', () {
    expect(matchTrackTitle('four houndred four', ['404Heart']), 0);
    expect(matchTrackTitle('404', ['404Heart', '404']), 1);
    expect(matchTrackTitle('404', ['404 Heart', '404 Live']), -1);
    expect(matchTrackTitle('404', ['4040']), -1);
    expect(matchTrackTitle('', ['404']), -1);
  });
}
