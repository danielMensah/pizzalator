// Pure Dart. No Flutter imports. The live notification while the app is
// hidden: the run laid out as frames for the native side to step through
// (android/.../LiveTimerState.kt), and the taps made there replayed.
import 'timer_run.dart';

/// The button a waiting frame offers: Start, Done, next or Finish.
enum LiveGo { start, next, finish }

/// What the notification shows from [at] on; [at] and [end] are offsets
/// from its leg's start. A timer frame counts down to [end]; a waiting frame
/// ([end] null) ends its leg until [go] is tapped. [chime]: the frame begins
/// because a timer ended.
class LiveFrame {
  const LiveFrame({
    required this.at,
    this.end,
    required this.title,
    required this.text,
    this.chime = false,
    this.go,
  });

  final Duration at;
  final Duration? end;
  final String title, text;
  final bool chime;
  final LiveGo? go;

  Map<String, Object?> toJson() => {
    'at': at.inMilliseconds,
    'end': end?.inMilliseconds,
    'title': title,
    'text': text,
    'chime': chime,
    'go': go?.name,
  };
}

/// A notification button. Native logs Finish as next.
enum LiveTap { pause, resume, extend, start, next }

/// A tap made on the notification, read back from the native log.
class LiveAction {
  const LiveAction(this.type, this.at);

  factory LiveAction.fromJson(Map<String, Object?> json) => LiveAction(
    LiveTap.values.byName(json['type'] as String),
    DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
  );

  final LiveTap type;
  final DateTime at;
}

/// [run] from [now] on, through TimerRun's own transitions. A leg runs by
/// itself (timer ends chain) up to a waiting frame; the next leg starts at
/// that tap. A paused run is laid out as if resumed now: native starts it
/// paused.
List<List<LiveFrame>> liveLegs(TimerRun run, DateTime now) {
  var r = run.settle(now);
  if (r.phaseAt(now) == RunPhase.paused) r = r.start(now);
  final legs = <List<LiveFrame>>[];
  for (var t = now; ;) {
    final start = t;
    final leg = <LiveFrame>[];
    TimerRun? done; // whose timer just ended, if one did
    while (r.phaseAt(t) == RunPhase.running) {
      leg.add(
        LiveFrame(
          at: t.difference(start),
          end: r.endsAt!.difference(start),
          title: r.step.name,
          text: _after(
            done,
            r.isLast ? 'Last step' : 'Next: ${r.nextStep!.name}',
          ),
          chime: done != null,
        ),
      );
      done = r;
      t = r.endsAt!;
      r = r.settle(t);
    }
    final ended = r.phaseAt(t) == RunPhase.ended;
    final timed = !ended && isTimed(r.step);
    final go = timed
        ? LiveGo.start
        : r.isLast
        ? LiveGo.finish
        : LiveGo.next;
    final tap = switch (go) {
      LiveGo.start => 'Start',
      LiveGo.next => 'Done, next',
      LiveGo.finish => 'Finish',
    };
    final note = r.step.note.isNotEmpty
        ? r.step.note
        : 'Tap $tap when ${timed ? 'ready' : 'finished'}';
    leg.add(
      LiveFrame(
        at: t.difference(start),
        title: ended ? r.alarm.title : r.step.name,
        text: ended ? r.alarm.body : _after(done, note),
        chime: done != null,
        go: go,
      ),
    );
    legs.add(leg);
    switch (go) {
      case LiveGo.start:
        r = r.start(t);
      case LiveGo.next:
        r = r.next(t)!;
      case LiveGo.finish:
        return legs;
    }
  }
}

/// A frame a timer end leads into says which end it was.
String _after(TimerRun? done, String text) =>
    done == null ? text : '${done.alarm.title} · $text';

/// [run] after the taps made on the notification, each on the run settled
/// at its time. Null once Finish ended the routine.
TimerRun? replayLive(TimerRun run, List<LiveAction> log) {
  TimerRun? r = run;
  for (final LiveAction(:type, :at) in log) {
    final s = r?.settle(at);
    if (s == null) return null;
    r = switch (type) {
      LiveTap.pause => s.pause(at),
      LiveTap.resume || LiveTap.start => s.start(at),
      LiveTap.extend => s.extend(at),
      LiveTap.next => s.next(at),
    };
  }
  return r;
}
