import 'package:flutter/foundation.dart';

/// One speaker, one sound.
///
/// Every player in the app — the clip rows, the continuous player — claims
/// this bus before it makes a noise and gives it up when it falls silent.
/// Whoever claims it last wins; everyone else stops. That has to be app-wide
/// rather than per screen, because clips also live in bottom sheets and
/// drawers laid over a screen that has clips of its own, and a listener
/// comparing takes should never end up with two of them overlapping.
///
/// Recording claims it too, as a player does: tapping the mic is a decision
/// to speak, not to speak over playback - and tapping play is a decision
/// to listen, not to record what the speaker is saying. Whichever came
/// second wins, and the other stops. A recorder watches the bus as a
/// player does, and ends its recording when something else takes it.
class AudioBus {
  AudioBus._();

  static final AudioBus instance = AudioBus._();

  /// Whoever is making a sound right now, or null. Players hold their own
  /// [State] as the token, so identity is guaranteed unique without anyone
  /// having to invent an id.
  final ValueNotifier<Object?> _owner = ValueNotifier<Object?>(null);

  void addListener(VoidCallback listener) => _owner.addListener(listener);

  void removeListener(VoidCallback listener) => _owner.removeListener(listener);

  bool holds(Object owner) => identical(_owner.value, owner);

  /// Whether nothing is playing or being recorded.
  bool get silent => _owner.value == null;

  /// Takes the speaker, stopping whoever had it.
  void claim(Object owner) {
    if (!holds(owner)) _owner.value = owner;
  }

  /// Gives the speaker up, if this owner still has it. A player that has
  /// already been supplanted must not clear the new owner's claim.
  void release(Object owner) {
    if (holds(owner)) _owner.value = null;
  }

  /// Silences whatever is playing, and ends any recording.
  void silence() => _owner.value = null;

  /// What a recording says when playback has ended it.
  static const String recordingStoppedMessage =
      'Recording stopped because audio started playing.';
}
