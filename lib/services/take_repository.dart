import 'package:flutter/foundation.dart';
import 'package:get/get.dart' show Trans;

import 'package:livuka/services/qc_feedback.dart';

import 'dart:convert';

import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/work_queue.dart';

/// One recording of one passage.
class Take {
  const Take({
    required this.id,
    required this.leafType,
    required this.leafId,
    required this.setId,
    required this.audioPath,
    required this.durationMs,
    required this.qcNotes,
    required this.status,
    required this.recordedAt,
    required this.isLocal,
    this.qcChecks = const [],
    this.qcSummary = '',
    this.blockedReason = '',
  });

  /// Why this take can no longer be Final, when a whole-Set send-back took
  /// the mark off it: the website's `blocked_reason`, shown as a "Sent
  /// back" pill on the take.
  final String blockedReason;
  bool get wasSentBack => blockedReason.isNotEmpty;

  final String id;
  final String leafType;
  final String leafId;
  final String setId;

  /// A device file path for a recording made here, a server URL for one that
  /// came down with the data load. Both play the same way once the audio
  /// cache has run.
  final String audioPath;
  final int durationMs;

  /// One line per failed check, as the last QC run left it.
  final String qcNotes;
  final String status;
  final String recordedAt;

  /// Recorded on this device, so it exists nowhere else yet.
  final bool isLocal;

  /// The QC report stored with the take, one entry per check.
  final List<QcCheck> qcChecks;

  /// The report's own verdict on the recording: "Good", "Average", "Poor".
  final String qcSummary;

  bool get passedQc => status == 'passed_qc';

  bool get hasQcReport => qcChecks.isNotEmpty || qcSummary.isNotEmpty;

  Duration get duration => Duration(milliseconds: durationMs);
}

/// One line of a QC report: what was measured, and how it came out.
class QcCheck {
  const QcCheck({
    required this.label,
    required this.detail,
    required this.passed,
    this.key = '',
    this.template = '',
    this.params = const {},
  });

  /// The check's name as the analyzer files it, for the words shown
  /// under it; empty in a report from before it was kept.
  final String key;

  final String label;

  /// The detail as the report stored it, in English.
  final String detail;

  /// The same with its numbers held apart, when the report kept them -
  /// a report from before that has only [detail].
  final String template;
  final Map<String, String> params;

  final bool passed;

  /// What the screen says under the check's name - see
  /// `QcCheckResult.shown`. The measured detail when the report is too
  /// old to say which check it was.
  String get shown {
    final feedback = QcFeedback.of(key, passed: passed);
    if (feedback.isNotEmpty) return feedback;
    return template.isEmpty ? detail : template.trParams(params);
  }
}

/// A mark left on a passage by whoever was reviewing it.
class TakeComment {
  const TakeComment({
    required this.id,
    required this.leafId,
    required this.text,
    required this.audioPath,
    required this.authorName,
    required this.stageKey,
    required this.status,
    required this.positionSeconds,
    required this.createdAt,
    required this.isLocal,
    this.takeId = '',
    this.type = 'comment',
    this.parentId = '',
    this.isMine = false,
    this.leafType = 'passage',
  });

  final String id;
  final String leafId;

  /// `passage` or `sub_passage`. The id alone does not say which: the two
  /// are numbered separately.
  final String leafType;

  /// The leaf this is about, as [SetLeaf.key] names it.
  String get leafKey => leafId.isEmpty ? '' : SetLeaf.keyOf(leafType, leafId);
  final String text;

  /// The take that was playing when this was written. A comment is about a
  /// recording, and once the drafter has replaced that recording it is about
  /// something nobody will hear again.
  final String takeId;

  /// `comment`, `question`, `answer` or `reply` - one table, four kinds.
  final String type;
  final String parentId;

  /// Whether the signed-in user wrote it. Only the author may delete.
  final bool isMine;

  /// A mark can be spoken instead of written.
  final String audioPath;
  final String authorName;
  final String stageKey;
  final String status;

  /// Where in the take the reviewer was listening, if they marked a point
  /// rather than the passage as a whole.
  final double? positionSeconds;
  final String createdAt;
  final bool isLocal;

  bool get isOpen => status == 'open';
  bool get hasAudio => audioPath.isNotEmpty;

  String get positionLabel {
    final seconds = positionSeconds;
    if (seconds == null) return '';
    final whole = seconds.round();
    return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
  }
}

/// A community-test question and whatever has been answered to it.
///
/// Questions are `take_comments` rows of type `question`; answers are rows of
/// type `answer` pointing back through `parent_id`. Either can be text or a
/// recording, because a community member who cannot read still has to be able
/// to ask and be asked.
class CommunityQuestion {
  const CommunityQuestion({
    required this.id,
    required this.text,
    required this.audioPath,
    required this.leafType,
    required this.leafId,
    required this.leafLabel,
    required this.positionSeconds,
    required this.createdAt,
    required this.answer,
    required this.replies,
    required this.isLocal,
    this.takeId = '',
    this.reaction,
    this.isMine = false,
  });

  final String id;

  /// The final take the question was asked about. Once the drafter records
  /// over it the question is about a reading nobody will hear again.
  final String takeId;

  /// The reviewer's verdict on the answer: a Like or a Dislike, one per
  /// answer, the newest replacing the last.
  final CommunityReaction? reaction;

  final bool isMine;

  /// The leaf this was asked about, as [SetLeaf.key] names it. Empty for a
  /// general question.
  String get leafKey => leafId.isEmpty ? '' : SetLeaf.keyOf(leafType, leafId);

  bool get isLiked => reaction?.isLike ?? false;
  bool get isDisliked => reaction?.isDislike ?? false;

  /// A question can carry both: typed wording plus a recording of it being
  /// asked aloud. The web shows the text and the player side by side, so
  /// neither is treated as a fallback for the other.
  final String text;
  final String audioPath;

  /// Empty for a question asked about the Set as a whole.
  final String leafType;
  final String leafId;
  final String leafLabel;

  /// Where in the merged recording the question was pinned.
  final double? positionSeconds;
  final String createdAt;

  /// One answer per question, matching the web's `$qa['answer']`.
  final CommunityAnswer? answer;

  /// What the reviewer said back about the question or its answer. A
  /// community review is a conversation on top of the test, not a rerun.
  final List<CommunityAnswer> replies;
  final bool isLocal;

  bool get hasAudio => audioPath.isNotEmpty;
  bool get isAnswered => answer != null;
  bool get hasReplies => replies.isNotEmpty;
  bool get isGeneral => leafId.isEmpty;

  /// The label the card's pill shows.
  String get displayText => text.isNotEmpty ? text : 'Voice question'.tr;
}

/// A Like or a Dislike on a community answer.
///
/// Stored the way the website stores it: a `reply` whose parent is the
/// ANSWER, carrying `reaction`. A Like is kept `resolved` - nothing is wrong
/// - and a Dislike `open`, which is what makes it count as a reason to send
/// the Set back and what clears the passage's final take when it goes.
class CommunityReaction {
  const CommunityReaction({
    required this.id,
    required this.reaction,
    required this.text,
    required this.audioPath,
    required this.authorName,
    required this.isLocal,
    this.status = 'open',
  });

  final String id;
  final String reaction;

  /// A Dislike stays open until the drafter has put a new take forward;
  /// a Like is stored resolved.
  final String status;
  bool get isOpen => status == 'open';
  final String text;
  final String audioPath;
  final String authorName;
  final bool isLocal;

  bool get isLike => reaction == 'like';
  bool get isDislike => reaction == 'dislike';
  bool get hasAudio => audioPath.isNotEmpty;
  bool get hasComment => text.isNotEmpty || audioPath.isNotEmpty;
}

class CommunityAnswer {
  const CommunityAnswer({
    required this.id,
    required this.text,
    required this.audioPath,
    required this.isLocal,
  });

  final String id;
  final String text;
  final String audioPath;
  final bool isLocal;

  bool get hasAudio => audioPath.isNotEmpty;
}

/// The current back translation of a Set, as the back translator left it.
class BackTranslation {
  const BackTranslation({
    required this.id,
    required this.text,
    required this.audioPath,
    required this.isLocal,
  });

  final String id;
  final String text;
  final String audioPath;
  final bool isLocal;

  bool get hasAudio => audioPath.isNotEmpty;
  bool get isEmpty => text.isEmpty && audioPath.isEmpty;
}

/// Every write a work screen can make. Each one lands in sqflite and stops
/// there.
///
/// Nothing is uploaded: the device is the record. A later sync will read
/// these tables and send them, so a write only has to leave enough behind for
/// that - which is why local rows keep their own ids and are never wiped by a
/// data load.
class TakeRepository {
  TakeRepository._();

  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// The QC report, however it was stored - the API sends an object, and a
  /// row that has been through JSON encoding may carry it as a string.
  /// Now, in the shape the server's tables hold a timestamp: UTC, to the
  /// second, space separated. Dart's own ISO string is none of those - it is
  /// local time with a `T` and microseconds, which a MySQL `timestamp`
  /// column will not take as written, and which sorts against the rows that
  /// come down from the server as though a `T` were later than every hour of
  /// the day.
  static String _serverNow() => _serverTime(DateTime.now());

  static String _serverTime(DateTime moment) {
    final at = moment.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');

    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  static Map<String, dynamic>? _qcResults(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<QcCheck> _qcChecks(Map<String, dynamic>? report) {
    final checks = report?['checks'];
    if (checks is! List) return const [];

    return [
      for (final check in checks)
        if (check is Map)
          QcCheck(
            key: _str(check['key']),
            label: _str(check['label']),
            detail: _str(check['detail']),
            passed: _str(check['status']).toLowerCase() == 'pass',
            template: _str(check['template']),
            params: {
              if (check['params'] is Map)
                for (final entry in (check['params'] as Map).entries)
                  entry.key.toString(): entry.value.toString(),
            },
          ),
    ];
  }

  static Future<List<Take>> takesFor({
    required String setId,
    required String leafType,
    required String leafId,
  }) async {
    final rows = await _db.getCollectionRows('takes');
    final result = <Take>[];
    final seen = <String>{};

    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final take = Map<String, dynamic>.from(payload);
      if (_str(take['obt_set_id']) != setId) continue;
      if (_str(take['leaf_type']) != leafType) continue;
      if (_str(take['leaf_id']) != leafId) continue;
      if (_str(take['status']) == 'trashed') continue;

      final id = _str(take['id']);
      if (id.isEmpty || !seen.add(id)) continue;

      final report = _qcResults(take['qc_results']);
      final summary = _str(report?['status']);
      final stored = _str(take['status']);

      result.add(
        Take(
          id: id,
          leafType: _str(take['leaf_type']),
          leafId: _str(take['leaf_id']),
          setId: setId,
          audioPath: _str(take['audio_path']),
          durationMs: int.tryParse(_str(take['duration_ms'])) ?? 0,
          // The report is the verdict, wherever the take was checked. "Good"
          // is the one that counts as a pass - anything less was flagged for
          // a reason, and leaves the take as the recording it already was.
          // A take the server calls passed with no report attached - checked
          // on the website before reports were kept - has still passed.
          status: stored == 'trashed'
              ? stored
              : summary.toLowerCase() == 'good' ||
                    (summary.isEmpty && stored == 'passed_qc')
              ? 'passed_qc'
              : 'recorded',
          qcNotes: _str(take['qc_notes']),
          qcChecks: _qcChecks(report),
          qcSummary: summary,
          recordedAt: _str(take['recorded_at']),
          isLocal: take[DatabaseHelper.localFlag] == true,
          blockedReason: _str(take['blocked_reason']),
        ),
      );
    }

    // Parsed, not compared as text: takes recorded here and takes that came
    // down from the server are both dated, but only one of them used to be
    // written with a `T`, and 'T' sorts after every digit.
    result.sort((a, b) => _time(a.recordedAt).compareTo(_time(b.recordedAt)));
    return result;
  }

  /// A stored timestamp as a time. Anything unreadable sorts first, which
  /// puts a take with no usable date at the bottom of the list rather than
  /// letting it throw.
  ///
  /// Read as UTC when it does not say otherwise. The rows written here are
  /// stamped in UTC without a zone (`2026-09-10 03:16:32`, the shape MySQL
  /// holds), while the ones the server sends end in `Z` - and Dart reads a
  /// zoneless string as LOCAL time. Compared as they stood, a take recorded
  /// on a phone in India looked five and a half hours older than a comment
  /// written on the website in the same minute, which is enough to decide
  /// "was this recorded after that was said" the wrong way round.
  static DateTime _time(String value) {
    final text = value.trim();
    if (text.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

    final zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(text);
    return DateTime.tryParse(
          zoned ? text : '${text.replaceFirst(' ', 'T')}Z',
        ) ??
        DateTime.tryParse(text) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Whether something a reviewer or drafter attached to a leaf - a comment,
  /// a community question - is still about the recording now going forward.
  /// The website's `SetLeaves::isCurrentForLeaf`:
  ///
  /// * no Final take yet: nothing to compare against, so it stands;
  /// * it names its take: it stands while that take is the Final one;
  /// * it names none - everything made on the website's older screens, and
  ///   every community question made on the website at all: it stands until
  ///   a take recorded AFTER it was written becomes Final, that later take
  ///   being the drafter's answer to it.
  ///
  /// [finalTake] is the leaf's Final take row, or null.
  static bool isCurrentFor({
    required Map<String, dynamic>? finalTake,
    required String takeId,
    required String createdAt,
  }) {
    if (finalTake == null) return true;
    if (takeId.isNotEmpty) return _str(finalTake['id']) == takeId;

    final recordedAt = _str(finalTake['recorded_at']);
    if (recordedAt.isEmpty || createdAt.trim().isEmpty) return true;
    return _time(recordedAt).isBefore(_time(createdAt));
  }

  /// The take id currently marked Final for this leaf, if any.
  static Future<String?> finalTakeId({
    required String leafType,
    required String leafId,
  }) async {
    for (final row in await _db.getCollectionRows('final_takes')) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      if (_str(payload['leaf_type']) != leafType) continue;
      if (_str(payload['leaf_id']) != leafId) continue;

      final takeId = _str(payload['take_id']);
      if (takeId.isNotEmpty) return takeId;
    }
    return null;
  }

  /// Stores a finished recording. Returns the local id the take answers to.
  static Future<String> saveTake({
    required String setId,
    required String leafType,
    required String leafId,
    required String filePath,
    required int durationMs,

    /// When the drafter started speaking. Left out only where that is not
    /// known, in which case the moment of saving stands in.
    DateTime? recordedAt,
  }) async {
    // The first take ever recorded on a Set is what moves it out of
    // `not_started` - still the drafter's stage, but no longer a blank
    // one. Only from that status, so a Set at redo or peer is left alone.
    await _db.updateRowById(
      table: 'sets',
      id: setId,
      update: (set) => set['workflow_status'] == 'not_started'
          ? {
              ...set,
              'workflow_status': 'recorded',
              'workflow_updated_at': _serverNow(),
            }
          : set,
    );

    final localId = await _db.insertLocalRow(
      table: 'takes',
      payload: {
        'leaf_type': leafType,
        'leaf_id': leafId,
        'obt_set_id': setId,
        'recorded_by': SessionService.userId?.toString() ?? '',
        'audio_path': filePath,
        'duration_ms': durationMs,
        'status': 'recorded',
        'qc_notes': '',
        // The start of the take, not the end of it. Saving happens when
        // recording stops, and a passage can run for minutes - stamping it
        // then puts the take on the timeline after everything the drafter
        // did while it was still running.
        'recorded_at': _serverTime(recordedAt ?? DateTime.now()),
      },
    );

    await ActivityLog.record(
      'take_recorded',
      setId: setId,
      details: {'leaf_type': leafType, 'leaf_id': leafId},
    );
    return localId;
  }

  /// Stores a QC verdict, in the same shape the server sends one.
  ///
  /// A take checked here and a take checked elsewhere are then read the same
  /// way - the screen has one report to show, not two formats to tell apart.
  ///
  /// Answers true when the take was the passage's Final one and this result
  /// took that away, so the screen can say so.
  static Future<bool> setQc({
    required String takeId,
    required String setId,
    required bool passed,
    required String notes,
    Map<String, dynamic> report = const {},
  }) async {
    await _db.updateRowById(
      table: 'takes',
      id: takeId,
      update: (payload) => {
        ...payload,
        // Three states only: `recorded` when it is made, `passed_qc` once QC
        // is happy with it, `trashed` when it is thrown away. A take that
        // fails its checks has not changed state - it is still a recording
        // waiting for something better, and the report says what was wrong
        // with it. One that passed before and does not now goes back to
        // `recorded` too: the earlier verdict no longer holds.
        'status': passed ? 'passed_qc' : 'recorded',
        'qc_notes': notes,
        if (report.isNotEmpty) 'qc_results': report,
      },
    );

    if (passed) return false;

    // The website's `qcCheckTake`: a take that is the passage's Final one
    // and has just stopped passing loses the mark. It was made Final on the
    // strength of a verdict that has now been contradicted - most often
    // because the source recording it is measured against was not on the
    // phone the first time - and a take that fails QC must not go on being
    // the passage's answer just because nobody looked again. A Good result
    // never needs this; it can only confirm a Final, not undermine one.
    var wasFinal = false;
    for (final row in await _db.getCollectionRows('final_takes')) {
      final payload = row['payload'];
      if (payload is Map && _str(payload['take_id']) == takeId) wasFinal = true;
    }
    if (!wasFinal) return false;

    await _db.deleteWhereField(
      table: 'final_takes',
      field: 'take_id',
      value: takeId,
    );
    return true;
  }

  /// Throws away the takes of [setId] that lost out - the website's
  /// `trashLowQualityTakes` and `trashCommentedTakes`, run as the drafter
  /// sends the Set on.
  ///
  /// A take graded Average or Bad already lost to whichever take was made
  /// Final; left on the passage it only clutters the Takes screen, and on
  /// the next round somebody may mistake it for a live option. So does a
  /// take a reviewer pinned a comment to: it is the very recording that had
  /// the Set sent back, and the drafter fixing it and moving on is the end
  /// of it. The Final take is never touched, whatever its grade - taking
  /// that away is a decision, made elsewhere, not a side effect.
  static Future<int> trashLosingTakes({required String setId}) async {
    final finals = <String>{};
    for (final row in await _db.getCollectionRows('final_takes')) {
      final payload = row['payload'];
      if (payload is Map) finals.add(_str(payload['take_id']));
    }

    final commented = <String>{};
    for (final row in await _db.getCollectionRows('take_comments')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;
      if (_str(payload['type']) != 'comment') continue;
      final takeId = _leafId(payload['take_id']);
      if (takeId.isNotEmpty) commented.add(takeId);
    }

    var trashed = 0;
    for (final row in await _db.getCollectionRows('takes')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      final take = Map<String, dynamic>.from(payload);
      if (_str(take['obt_set_id']) != setId) continue;
      if (_str(take['status']) == 'trashed') continue;

      final id = _str(take['id']);
      if (id.isEmpty || finals.contains(id)) continue;

      final grade = _str(_qcResults(take['qc_results'])?['status']);
      final lowQuality = grade == 'Average' || grade == 'Bad';
      if (!lowQuality && !commented.contains(id)) continue;

      await _db.updateRowById(
        table: 'takes',
        id: id,
        update: (payload) => {...payload, 'status': 'trashed'},
      );
      trashed++;
    }
    return trashed;
  }

  /// Throws away every take of [setId] that was not chosen.
  ///
  /// Called when a Set leaves peer check: the peer has agreed the readings,
  /// so the rejected attempts have done their job. Keeping them costs a
  /// phone real space - a passage can carry six takes of a two-minute
  /// reading - and every later stage plays only the final one, so they are
  /// weight nobody downstream will ever open.
  ///
  /// Trashed rather than deleted, exactly as the drafter's bin does it: the
  /// row stays so the change can be sent, and it is the server that decides
  /// what becomes of the file.
  ///
  /// Returns how many were thrown away.
  static Future<int> trashUnusedTakes({required String setId}) async {
    // Any take that is final anywhere is spared. Take ids are unique, so
    // there is no need to work out which leaf each one belongs to.
    final chosen = <String>{};
    for (final row in await _db.getCollectionRows('final_takes')) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final takeId = _str(payload['take_id']);
      if (takeId.isNotEmpty) chosen.add(takeId);
    }

    var trashed = 0;

    for (final row in await _db.getCollectionRows('takes')) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final take = Map<String, dynamic>.from(payload);
      if (_str(take['obt_set_id']) != setId) continue;
      if (_str(take['status']) == 'trashed') continue;

      final id = _str(take['id']);
      if (id.isEmpty || chosen.contains(id)) continue;

      await _db.updateRowById(
        table: 'takes',
        id: id,
        update: (payload) => {...payload, 'status': 'trashed'},
      );
      trashed++;
    }

    return trashed;
  }

  /// `final_takes` is unique per leaf, so this replaces whatever was final
  /// before rather than adding a second row — the same thing the web app's
  /// `ON DUPLICATE KEY UPDATE` does.
  static Future<void> finalizeTake({
    required String takeId,
    required String setId,
    required String leafType,
    required String leafId,
  }) async {
    final blocked = await finalBlockedReason(
      setId: setId,
      takeId: takeId,
      leafType: leafType,
      leafId: leafId,
    );
    if (blocked != null) throw StateError(blocked);

    await _db.deleteWhereField(
      table: 'final_takes',
      field: 'leaf_id',
      value: leafId,
      // A passage and a sub passage can share a number.
      alsoField: 'leaf_type',
      alsoValue: leafType,
    );

    await _db.insertLocalRow(
      table: 'final_takes',
      payload: {
        'leaf_type': leafType,
        'leaf_id': leafId,
        'take_id': takeId,
        'finalized_by': SessionService.userId?.toString() ?? '',
        'finalized_at': _serverNow(),
      },
    );

    await _resolveLeafComments(
      setId: setId,
      leafType: leafType,
      leafId: leafId,
    );
    await ActivityLog.record(
      'take_final',
      setId: setId,
      details: {'take_id': takeId, 'leaf_type': leafType, 'leaf_id': leafId},
    );
  }

  /// The stages whose comments are about a recording, and so can stand in
  /// the way of a take being made Final. A consultant's comments are about
  /// the back translation, not a take.
  static const Set<String> _reviewStages = {
    'peer',
    'community_review',
    'back_translation',
  };

  /// Who a comment came from, the way the website says it in these messages.
  static String _reviewerLabel(String stageKey) => switch (stageKey) {
    'peer' => 'Peer Check',
    'community_review' => 'Community Review',
    'back_translation' => 'the Back Translator',
    _ => 'a reviewer',
  };

  /// Why [takeId] may not be made Final, or null when it may.
  ///
  /// The website's `DrafterController::finalizeTake`, rule for rule, because
  /// a drafter offline has nobody else to refuse them:
  ///
  /// 1. A reviewer's comment pinned to THIS take blocks it - open or
  ///    resolved. Status is deliberately not trusted: comments are resolved
  ///    automatically when some other take becomes Final, which says nothing
  ///    about whether this recording's fault was fixed. It cannot have been;
  ///    a recording does not change. The only way past is a new take.
  /// 2. A take the server marked `blocked_reason` - it was Final when the
  ///    whole Set was sent back - says why itself.
  /// 3. An open community-review reply (a Dislike) whose question was about
  ///    this take blocks it the same way.
  /// 4. Comments from before take ids were recorded cannot name a take, so
  ///    the old rule stands for them: an open one blocks every take recorded
  ///    before it was written.
  static Future<String?> finalBlockedReason({
    required String setId,
    required String takeId,
    required String leafType,
    required String leafId,
  }) async {
    final comments = <Map<String, dynamic>>[];
    for (final row in await _db.getCollectionRows('take_comments')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;
      if (payload[DatabaseHelper.deletedFlag] == true) continue;
      comments.add(Map<String, dynamic>.from(payload));
    }

    bool onThisLeaf(Map<String, dynamic> row) =>
        _str(row['leaf_type']) == leafType && _leafId(row['leaf_id']) == leafId;

    // The takes of this passage, oldest first, and this one among them.
    final takes = <Map<String, dynamic>>[];
    for (final row in await _db.getCollectionRows('takes')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['leaf_type']) != leafType) continue;
      if (_str(payload['leaf_id']) != leafId) continue;
      if (_str(payload['status']) == 'trashed') continue;
      takes.add(Map<String, dynamic>.from(payload));
    }
    takes.sort(
      (a, b) =>
          _time(_str(a['recorded_at']))
              .compareTo(_time(_str(b['recorded_at']))),
    );
    final take = takes.where((t) => _str(t['id']) == takeId).firstOrNull;

    // 1. A comment on this very take, whatever its status.
    for (final comment in comments) {
      if (_str(comment['type']) != 'comment') continue;
      if (!_reviewStages.contains(_str(comment['stage_key']))) continue;
      if (!onThisLeaf(comment)) continue;
      if (_leafId(comment['take_id']) != takeId) continue;

      return 'This take was sent back with a comment from @reviewer - record '
              'a new take to fix it before marking one Final.'
          .trParams({
            'reviewer': _reviewerLabel(_str(comment['stage_key'])).tr,
          });
    }

    // 2. Swept up in a whole-Set send-back.
    final blocked = _str(take?['blocked_reason']);
    if (blocked.isNotEmpty) return blocked.tr;

    // 3. A Dislike whose question was about this take.
    final byId = {for (final row in comments) _str(row['id']): row};
    final finalTakeId = (await _finalTakeIdByLeaf())['$leafType|$leafId'];

    for (final reply in comments) {
      if (_str(reply['type']) != 'reply') continue;
      if (_str(reply['stage_key']) != 'community_review') continue;
      if (_str(reply['status']) != 'open') continue;

      // Reply -> answer -> question. Replies made by an early build of this
      // app hang off the question directly.
      final parent = byId[_leafId(reply['parent_id'])];
      final question = parent == null
          ? null
          : _str(parent['type']) == 'question'
          ? parent
          : byId[_leafId(parent['parent_id'])];
      if (question == null || !onThisLeaf(question)) continue;

      if (_questionTakeId(question, takes, finalTakeId) == takeId) {
        return 'This take was sent back with a reply from @reviewer - record '
                'a new take to fix it before marking one Final.'
            .trParams({'reviewer': _reviewerLabel('community_review').tr});
      }
    }

    // 4. Legacy comments with no take id: the newest open one blocks every
    // take recorded at or before it.
    Map<String, dynamic>? legacy;
    for (final comment in comments) {
      if (_str(comment['type']) != 'comment') continue;
      if (!_reviewStages.contains(_str(comment['stage_key']))) continue;
      if (!onThisLeaf(comment)) continue;
      if (_leafId(comment['take_id']).isNotEmpty) continue;
      if (_str(comment['status']) != 'open') continue;

      if (legacy == null ||
          _time(_str(comment['created_at']))
              .isAfter(_time(_str(legacy['created_at'])))) {
        legacy = comment;
      }
    }
    final recordedAt = _str(take?['recorded_at']);
    if (legacy != null &&
        recordedAt.isNotEmpty &&
        !_time(recordedAt).isAfter(_time(_str(legacy['created_at'])))) {
      return 'This passage was sent back with a comment from @reviewer - '
              'record a new take to fix it before marking one Final.'
          .trParams({'reviewer': _reviewerLabel(_str(legacy['stage_key'])).tr});
    }

    return null;
  }

  /// Which take a community question was about - the website's
  /// `resolveQaTakeId`. Its own `take_id` when it has one; otherwise the
  /// take recorded most recently at or before the question was written,
  /// since anything later is an attempt to fix it; failing that the Final
  /// take, and failing that the first take there is.
  static String? _questionTakeId(
    Map<String, dynamic> question,
    List<Map<String, dynamic>> takesOldestFirst,
    String? finalTakeId,
  ) {
    final own = _leafId(question['take_id']);
    if (own.isNotEmpty) return own;

    final asked = _str(question['created_at']);
    if (asked.isNotEmpty) {
      for (final take in takesOldestFirst.reversed) {
        final recorded = _str(take['recorded_at']);
        if (recorded.isEmpty) continue;
        if (!_time(recorded).isAfter(_time(asked))) return _str(take['id']);
      }
    }

    return finalTakeId ?? takesOldestFirst.firstOrNull?['id']?.toString();
  }

  /// A new take has been made Final, which is the drafter's answer to every
  /// open comment on the passage: they describe a recording that is no
  /// longer the one going forward. Closed here, as the website does, so they
  /// stop showing as outstanding against a passage that has been redone.
  static Future<void> _resolveLeafComments({
    required String setId,
    required String leafType,
    required String leafId,
  }) async {
    for (final row in await _db.getCollectionRows('take_comments')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;
      if (_str(payload['type']) != 'comment') continue;
      if (_str(payload['status']) != 'open') continue;
      if (!_reviewStages.contains(_str(payload['stage_key']))) continue;
      if (_str(payload['leaf_type']) != leafType) continue;
      if (_leafId(payload['leaf_id']) != leafId) continue;

      await _db.updateRowById(
        table: 'take_comments',
        id: _str(payload['id']),
        update: (comment) => {...comment, 'status': 'resolved'},
      );
    }
  }

  static Future<void> unfinalizeTake({
    required String takeId,
    required String setId,
  }) async {
    await _db.deleteWhereField(
      table: 'final_takes',
      field: 'take_id',
      value: takeId,
    );
  }

  /// Marks a take as thrown away without removing it.
  ///
  /// The row is what a later sync will send, and a row that is gone says
  /// nothing - the server would never learn the take was discarded. So the
  /// take is marked `trashed` instead, which every read already skips, and
  /// its recording stays on the device until the Set is next loaded fresh.
  static Future<void> deleteTake({
    required String takeId,
    required String setId,
  }) async {
    await _db.deleteWhereField(
      table: 'final_takes',
      field: 'take_id',
      value: takeId,
    );
    await _db.updateRowById(
      table: 'takes',
      id: takeId,
      update: (payload) => {...payload, 'status': 'trashed'},
    );
    await ActivityLog.record(
      'take_deleted',
      setId: setId,
      details: {'take_id': takeId},
    );
  }

  /// Every mark left on one passage, oldest first, replies included.
  static Future<List<TakeComment>> commentsFor({
    required String setId,
    required String leafType,
    required String leafId,
  }) async {
    final rows = await _db.getCollectionRows('take_comments');
    final names = await userNames();
    final result = <TakeComment>[];
    final seen = <String>{};

    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final comment = Map<String, dynamic>.from(payload);
      if (_str(comment['obt_set_id']) != setId) continue;
      if (_str(comment['leaf_type']) != leafType) continue;
      if (_str(comment['leaf_id']) != leafId) continue;
      if (comment[DatabaseHelper.deletedFlag] == true) continue;
      // Only what a reviewer marked on the recording. Questions, answers and
      // replies share this table and are pinned to passages too, and listing
      // them here put a community question under "why this was sent back".
      if (_str(comment['type']) != 'comment') continue;

      final id = _str(comment['id']);
      if (id.isEmpty || !seen.add(id)) continue;

      result.add(_comment(comment, names));
    }

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  static TakeComment _comment(
    Map<String, dynamic> comment,
    Map<String, String> names,
  ) => TakeComment(
    id: _str(comment['id']),
    leafId: _leafId(comment['leaf_id']),
    leafType: _str(comment['leaf_type']),
    takeId: _leafId(comment['take_id']),
    type: _str(comment['type']),
    parentId: _leafId(comment['parent_id']),
    text: _str(comment['text']),
    audioPath: _str(comment['audio_path']),
    authorName: authorNameOf(comment, names),
    stageKey: _str(comment['stage_key']),
    status: _str(comment['status']),
    positionSeconds: double.tryParse(_str(comment['position_seconds'])),
    createdAt: _str(comment['created_at']),
    isLocal: comment[DatabaseHelper.localFlag] == true,
    isMine: isMine(comment),
  );

  /// Who wrote [row], by name.
  ///
  /// The server's `take_comments` rows name their author only by
  /// `author_id`; the name lives in the `users` table that comes down with
  /// the same data load ([userNames]). A row written here carries
  /// `author_name` outright, and is used as it stands.
  static String authorNameOf(
    Map<String, dynamic> row,
    Map<String, String> names,
  ) {
    final stated = _str(row['author_name']);
    if (stated.isNotEmpty) return stated;
    return names[_str(row['author_id'])] ?? '';
  }

  /// Every user the data load brought down, id to name. The server sends
  /// everyone assigned to any of this user's Sets, which is everyone whose
  /// name a comment, question or reply here could need.
  static Future<Map<String, String>> userNames() async {
    final names = <String, String>{};
    for (final row in await _db.getCollectionRows('users')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      final id = _str(payload['id']);
      final name = _str(payload['name']);
      if (id.isNotEmpty && name.isNotEmpty) names.putIfAbsent(id, () => name);
    }
    return names;
  }

  /// Whether the signed-in user wrote [row].
  ///
  /// A row made on this phone and not yet sent can only be theirs. One that
  /// came from the server names its author by id, under whichever column the
  /// table uses.
  static bool isMine(Map<String, dynamic> row) {
    if (row[DatabaseHelper.localFlag] == true) return true;

    final me = SessionService.userId?.toString() ?? '';
    if (me.isEmpty) return false;

    for (final column in const ['author_id', 'user_id', 'created_by']) {
      if (row.containsKey(column)) return _str(row[column]) == me;
    }
    return false;
  }

  /// Every mark left anywhere in a Set, so the merged player can pin them
  /// all onto one timeline.
  static Future<List<TakeComment>> commentsForSet(
    String setId, {

    /// Also the replies made to those comments - the back translator's
    /// answers to the consultant.
    bool withReplies = false,
  }) async {
    final rows = await _db.getCollectionRows('take_comments');
    final names = await userNames();
    final result = <TakeComment>[];
    final seen = <String>{};

    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final comment = Map<String, dynamic>.from(payload);
      if (_str(comment['obt_set_id']) != setId) continue;
      // Matched positively rather than by excluding questions and answers:
      // take_comments also carries notes and replies, and only a plain
      // comment is a mark on the recording.
      final type = _str(comment['type']);
      if (type != 'comment' && !(withReplies && type == 'reply')) continue;
      if (comment[DatabaseHelper.deletedFlag] == true) continue;

      final id = _str(comment['id']);
      if (id.isEmpty || !seen.add(id)) continue;

      result.add(_comment(comment, names));
    }

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  /// Leaves a mark on a passage. [positionSeconds] is where in the take the
  /// reviewer paused, which is what makes a mark findable again.
  static Future<String> addComment({
    required String setId,
    required String leafType,
    required String leafId,
    required String stageKey,
    required String text,
    String? audioFilePath,
    String? takeId,
    double? positionSeconds,
  }) async {
    final localId = await _db.insertLocalRow(
      table: 'take_comments',
      payload: {
        'obt_set_id': setId,
        'leaf_type': leafType.isEmpty ? null : leafType,
        'leaf_id': leafId.isEmpty ? null : leafId,
        'take_id': (takeId ?? '').isEmpty ? null : takeId,
        'stage_key': stageKey,
        'type': 'comment',
        'position_seconds': positionSeconds,
        'text': text,
        'audio_path': audioFilePath ?? '',
        'author_name': 'You',
        'author_id': SessionService.userId?.toString() ?? '',
        'status': 'open',
        'created_at': _serverNow(),
      },
    );

    await ActivityLog.record(
      'comment_added',
      setId: setId,
      details: {'stage': stageKey, 'leaf_type': leafType, 'leaf_id': leafId},
    );
    return localId;
  }

  /// Every question asked about [setId], each carrying its answer.
  ///
  /// [leafLabels] maps a leaf's [SetLeaf.key] to its display name so a question can say
  /// "Passage 1" rather than a bare id.
  static Future<List<CommunityQuestion>> questionsFor({
    required String setId,
    required Map<String, String> leafLabels,

    /// Whether to leave out questions asked about a take that has since been
    /// replaced. Community Setup still lists them - that is where the drafter
    /// decides whether to ask again.
    bool currentOnly = true,

    /// Whether to leave out questions that have been closed - every question
    /// of an earlier community round, general ones included (see
    /// [closeCommunityRound]). Only the drafter's feedback reads those.
    bool openOnly = true,
  }) async {
    final rows = await _db.getCollectionRows('take_comments');
    final names = await userNames();

    final questions = <String, Map<String, dynamic>>{};
    final answerByParent = <String, CommunityAnswer>{};
    final replyRows = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final comment = Map<String, dynamic>.from(payload);
      if (_str(comment['obt_set_id']) != setId) continue;
      if (comment[DatabaseHelper.deletedFlag] == true) continue;

      final id = _str(comment['id']);
      if (id.isEmpty || !seen.add(id)) continue;

      final type = _str(comment['type']);
      if (type == 'question') {
        questions[id] = comment;
      } else if (type == 'reply') {
        if (_leafId(comment['parent_id']).isNotEmpty) replyRows.add(comment);
      } else if (type == 'answer') {
        final parent = _str(comment['parent_id']);
        if (parent.isEmpty) continue;
        // One answer per question; a repeat keeps the first seen.
        answerByParent.putIfAbsent(
          parent,
          () => CommunityAnswer(
            id: id,
            text: _str(comment['text']),
            audioPath: _str(comment['audio_path']),
            isLocal: comment[DatabaseHelper.localFlag] == true,
          ),
        );
      }
    }

    // A reply hangs off the ANSWER, the way the website files it. Ones made
    // by earlier builds of this app hang off the question instead, so both
    // are followed back to the question they are about.
    final questionByAnswer = {
      for (final entry in answerByParent.entries) entry.value.id: entry.key,
    };
    final reactionByQuestion = <String, CommunityReaction>{};
    final repliesByQuestion = <String, List<CommunityAnswer>>{};

    replyRows.sort(
      (a, b) =>
          _time(_str(b['created_at'])).compareTo(_time(_str(a['created_at']))),
    );
    for (final reply in replyRows) {
      final parent = _leafId(reply['parent_id']);
      final onAnswer = questionByAnswer.containsKey(parent);
      final questionId = questionByAnswer[parent] ?? parent;
      if (!questions.containsKey(questionId)) continue;

      final reaction = reactionOf(reply, onAnswer: onAnswer);
      if (reaction != null) {
        // Newest first, so the first one met is the verdict that stands.
        reactionByQuestion.putIfAbsent(
          questionId,
          () => CommunityReaction(
            id: _str(reply['id']),
            reaction: reaction,
            text: _str(reply['text']),
            audioPath: _str(reply['audio_path']),
            authorName: authorNameOf(reply, names),
            isLocal: reply[DatabaseHelper.localFlag] == true,
            status: _str(reply['status']),
          ),
        );
        continue;
      }

      repliesByQuestion
          .putIfAbsent(questionId, () => [])
          .add(
            CommunityAnswer(
              id: _str(reply['id']),
              text: _str(reply['text']),
              audioPath: _str(reply['audio_path']),
              isLocal: reply[DatabaseHelper.localFlag] == true,
            ),
          );
    }

    final finalByLeaf = await _finalTakeRowByLeaf();

    final result = <CommunityQuestion>[];
    for (final entry in questions.entries) {
      final question = entry.value;
      final leafId = _leafId(question['leaf_id']);
      final takeId = _leafId(question['take_id']);

      // Asked about a take the drafter has since replaced: the question, its
      // answer and the verdict on it all belong to a reading that is gone.
      // The website drops these the same way (`isCurrentForLeaf`) - and a
      // question made THERE carries no take id, so it is judged by date: an
      // old Dislike on it must not go on blocking a passage that has been
      // recorded again since.
      if (openOnly && _str(question['status']) == 'resolved') continue;

      if (currentOnly && leafId.isNotEmpty) {
        final current = isCurrentFor(
          finalTake: finalByLeaf['${_str(question['leaf_type'])}|$leafId'],
          takeId: takeId,
          createdAt: _str(question['created_at']),
        );
        if (!current) continue;
      }

      result.add(
        CommunityQuestion(
          id: entry.key,
          text: _str(question['text']),
          audioPath: _str(question['audio_path']),
          leafType: _str(question['leaf_type']),
          leafId: leafId,
          takeId: takeId,
          leafLabel:
              leafLabels[leafId.isEmpty
                  ? ''
                  : SetLeaf.keyOf(_str(question['leaf_type']), leafId)] ??
              '',
          positionSeconds: double.tryParse(_str(question['position_seconds'])),
          createdAt: _str(question['created_at']),
          answer: answerByParent[entry.key],
          reaction: reactionByQuestion[entry.key],
          replies: repliesByQuestion[entry.key] ?? const [],
          isLocal: question[DatabaseHelper.localFlag] == true,
          isMine: isMine(question),
        ),
      );
    }

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  /// The verdict a reply row carries, if it is one.
  ///
  /// `reaction` says it outright, and the server keeps it. A
  /// community-review reply filed against an answer with no `reaction` on
  /// it - one sent before the sync endpoint kept the column - is read by
  /// its status instead, because the two are always written together: a
  /// Like is stored resolved and a Dislike open.
  static String? reactionOf(
    Map<String, dynamic> reply, {
    required bool onAnswer,
  }) {
    final stated = _str(reply['reaction']).toLowerCase();
    if (stated == 'like' || stated == 'dislike') return stated;

    if (!onAnswer || _str(reply['stage_key']) != 'community_review') {
      return null;
    }
    return _str(reply['status']) == 'resolved' ? 'like' : 'dislike';
  }

  /// The Final take's own row for each leaf, keyed `leaf_type|leaf_id`.
  static Future<Map<String, Map<String, dynamic>>> _finalTakeRowByLeaf() async {
    final takes = <String, Map<String, dynamic>>{};
    for (final row in await _db.getCollectionRows('takes')) {
      final payload = row['payload'];
      if (payload is! Map || _str(payload['status']) == 'trashed') continue;
      takes.putIfAbsent(
        _str(payload['id']),
        () => Map<String, dynamic>.from(payload),
      );
    }

    final result = <String, Map<String, dynamic>>{};
    for (final entry in (await _finalTakeIdByLeaf()).entries) {
      final take = takes[entry.value];
      if (take != null) result[entry.key] = take;
    }
    return result;
  }

  /// Which take is final for each leaf, keyed `leaf_type|leaf_id`.
  static Future<Map<String, String>> _finalTakeIdByLeaf() async {
    final result = <String, String>{};
    for (final row in await _db.getCollectionRows('final_takes')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      final takeId = _str(payload['take_id']);
      if (takeId.isEmpty) continue;
      result.putIfAbsent(
        '${_str(payload['leaf_type'])}|${_str(payload['leaf_id'])}',
        () => takeId,
      );
    }
    return result;
  }

  /// Likes or dislikes the answer to [question], replacing any verdict
  /// already given. A Dislike has to say why - that is enforced where the
  /// composer is, and again here so nothing else can file a silent one.
  static Future<void> setReaction({
    required String setId,
    required CommunityQuestion question,
    required String reaction,
    String text = '',
    String? audioFilePath,
  }) async {
    final answer = question.answer;
    if (answer == null) {
      throw StateError('There is no answer to react to yet.');
    }
    final audio = audioFilePath ?? '';
    if (reaction == 'dislike' && text.isEmpty && audio.isEmpty) {
      throw StateError('A Dislike needs a comment.');
    }

    final status = reaction == 'like' ? 'resolved' : 'open';
    final existing = question.reaction;

    if (existing != null && !existing.isLocal) {
      await _db.updateRowById(
        table: 'take_comments',
        id: existing.id,
        update: (payload) => {
          ...payload,
          'reaction': reaction,
          'text': text,
          'status': status,
          if (audio.isNotEmpty) 'audio_path': audio,
        },
      );
      await ActivityLog.record(
        'review_verdict',
        setId: setId,
        details: {'reaction': reaction, 'question_id': question.id},
      );
      return;
    }
    if (existing != null) {
      await _db.deleteRowById(table: 'take_comments', id: existing.id);
    }

    await _db.insertLocalRow(
      table: 'take_comments',
      payload: {
        'obt_set_id': setId,
        'leaf_type': question.isGeneral ? null : question.leafType,
        'leaf_id': question.isGeneral ? null : question.leafId,
        'take_id': question.takeId.isEmpty ? null : question.takeId,
        'parent_id': answer.id,
        'stage_key': 'community_review',
        'type': 'reply',
        'reaction': reaction,
        'text': text,
        'audio_path': audio,
        'author_name': 'You',
        'author_id': SessionService.userId?.toString() ?? '',
        'status': status,
        'created_at': _serverNow(),
      },
    );
    await ActivityLog.record(
      'review_verdict',
      setId: setId,
      details: {'reaction': reaction, 'question_id': question.id},
    );
  }

  /// The questions whose answers a Community Review disliked and the
  /// drafter has still to act on - the website's `communityReviewQaChains`.
  /// Only while the Set is back with the drafter from that stage; every
  /// round's questions are read, since the disliked one is about the take
  /// that was Final then, not now.
  static Future<List<CommunityQuestion>> disputedQuestionsFor({
    required String setId,
    required Map<String, String> leafLabels,
  }) async {
    final all = await questionsFor(
      setId: setId,
      leafLabels: leafLabels,
      currentOnly: false,
      openOnly: false,
    );
    return [
      for (final question in all)
        if (question.isDisliked && (question.reaction?.isOpen ?? false))
          question,
    ];
  }

  /// Which take a question was about, the website's `resolveQaTakeId`:
  /// its own take when it names one, otherwise the take recorded most
  /// recently at or before it was asked, and failing that the first take.
  static String? takeOfQuestion(
    CommunityQuestion question,
    List<Take> takesOldestFirst,
  ) {
    if (question.takeId.isNotEmpty) return question.takeId;

    if (question.createdAt.isNotEmpty) {
      for (final take in takesOldestFirst.reversed) {
        if (take.recordedAt.isEmpty) continue;
        if (!_time(take.recordedAt).isAfter(_time(question.createdAt))) {
          return take.id;
        }
      }
    }
    return takesOldestFirst.firstOrNull?.id;
  }

  /// What the drafter is shown on their Feedback screen for [setId].
  ///
  /// Liked answers that came with a comment, on questions about a passage,
  /// while the take they were about is still the final one. A bare Like says
  /// nothing worth a screen, a Dislike arrives as a sent-back Set rather
  /// than as feedback, and a general question belongs to no recording.
  static Future<List<CommunityQuestion>> feedbackFor({
    required String setId,
    required Map<String, String> leafLabels,
  }) async {
    final all = await questionsFor(
      setId: setId,
      leafLabels: leafLabels,
      openOnly: false,
    );
    return [
      for (final question in all)
        if (!question.isGeneral &&
            question.isAnswered &&
            question.isLiked &&
            question.reaction!.hasComment)
          question,
    ];
  }

  /// Whether a send-back returns the whole Set or only the passages at
  /// fault: the project's `send_back_based_on`, `'take'` unless it says
  /// `'set'`. Read from wherever the data load put it - the Set's own row,
  /// or a settings block - so it is honoured the moment the server sends it.
  static Future<bool> sendBackWholeSet(String setId) async {
    for (final row in await _db.getCollectionRows('sets')) {
      final payload = row['payload'];
      if (payload is! Map || _str(payload['id']) != setId) continue;
      if (payload.containsKey('send_back_based_on')) {
        return _str(payload['send_back_based_on']) == 'set';
      }
    }
    return _str(await _db.setting('send_back_based_on')) == 'set';
  }

  /// Takes the Final mark off the leaves a reviewer has faulted, so the
  /// drafter is handed exactly what needs recording again.
  ///
  /// [leafKeys] are [SetLeaf.key]s; null means every leaf in the Set.
  static Future<void> _clearFinals(String setId, Set<String>? leafKeys) async {
    for (final leaf in await WorkQueue.leavesForSet(setId)) {
      if (leafKeys != null && !leafKeys.contains(leaf.key)) continue;

      // A whole-Set send-back takes the Final off passages nobody commented
      // on, and the take that was Final is stamped with why, so it cannot
      // simply be picked again untouched - the website's `clearForSet`.
      // A passage sent back for its own comment needs no stamp; the
      // comment on its take is what stops it.
      final wasFinal = leaf.finalTake?['id']?.toString() ?? '';
      if (leafKeys == null && wasFinal.isNotEmpty) {
        await _db.updateRowById(
          table: 'takes',
          id: wasFinal,
          update: (take) => {
            ...take,
            'blocked_reason':
                'Part of a whole-Set send back - record a new take to '
                'replace it.',
          },
        );
      }

      await _db.deleteWhereField(
        table: 'final_takes',
        field: 'leaf_id',
        value: leaf.id,
        // A passage and a sub-passage can share a number.
        alsoField: 'leaf_type',
        alsoValue: leaf.type,
      );
    }
  }

  /// Closes every open comment from [stageKey] that is no longer about the
  /// take now going forward - the website's `resolveSupersededComments`,
  /// which it runs before every check, forward and send-back.
  ///
  /// A comment is about one recording. Once the drafter has put a different
  /// take forward for that passage, the comment describes something nobody
  /// will hear again; left open, it would count as a reason to send the Set
  /// back and, on the way, take the Final mark off a passage that has
  /// already been redone.
  static Future<void> resolveSupersededComments({
    required String setId,
    required String stageKey,
  }) async {
    final finalByLeaf = {
      for (final leaf in await WorkQueue.leavesForSet(setId))
        leaf.key: leaf.finalTake,
    };

    for (final comment in await commentsForSet(setId)) {
      if (!comment.isOpen) continue;
      if (comment.stageKey != stageKey) continue;
      if (comment.leafId.isEmpty) continue;

      final finalTake = finalByLeaf[comment.leafKey];
      if (finalTake == null) continue;

      final current = isCurrentFor(
        finalTake: finalTake,
        takeId: comment.takeId,
        createdAt: comment.createdAt,
      );
      if (current) continue;

      await _db.updateRowById(
        table: 'take_comments',
        id: comment.id,
        update: (payload) => {...payload, 'status': 'resolved'},
      );
    }
  }

  /// The same for community-review replies - the Dislikes - which reach
  /// their passage through the question they answer. The website's
  /// `resolveSupersededReplies`.
  static Future<void> resolveSupersededReplies({required String setId}) async {
    // Read with the replaced ones still in: those are exactly the ones to
    // close.
    final questions = await questionsFor(
      setId: setId,
      leafLabels: const {},
      currentOnly: false,
    );
    final finalByLeaf = {
      for (final leaf in await WorkQueue.leavesForSet(setId))
        leaf.key: leaf.finalTake,
    };

    for (final question in questions) {
      final reaction = question.reaction;
      if (reaction == null || !reaction.isDislike || question.isGeneral) {
        continue;
      }

      final finalTake = finalByLeaf[question.leafKey];
      if (finalTake == null) continue;

      final current = isCurrentFor(
        finalTake: finalTake,
        takeId: question.takeId,
        createdAt: question.createdAt,
      );
      if (current) continue;

      await _db.updateRowById(
        table: 'take_comments',
        id: reaction.id,
        update: (payload) => {...payload, 'status': 'resolved'},
      );
    }
  }

  /// A peer-check or back-translation send-back: the passages carrying an
  /// open comment from [stageKey] lose their final take.
  ///
  /// Only a comment about the take now Final counts. One about a take the
  /// drafter has since replaced is closed first, as the website does, so a
  /// passage already redone is not cleared for a fault that is gone.
  static Future<void> clearFinalsForOpenComments({
    required String setId,
    required String stageKey,
  }) async {
    await resolveSupersededComments(setId: setId, stageKey: stageKey);

    if (await sendBackWholeSet(setId)) return _clearFinals(setId, null);

    final leaves = <String>{
      for (final comment in await commentsForSet(setId))
        if (comment.isOpen &&
            comment.stageKey == stageKey &&
            comment.leafId.isNotEmpty)
          comment.leafKey,
    };
    await _clearFinals(setId, leaves);
  }

  /// A community-review send-back: the passage each disliked answer belongs
  /// to loses its final take. A general question belongs to no passage, so
  /// a Dislike on one clears nothing.
  static Future<void> clearFinalsForReviewSendBack({
    required String setId,
  }) async {
    await resolveSupersededComments(setId: setId, stageKey: 'community_review');
    await resolveSupersededReplies(setId: setId);

    if (await sendBackWholeSet(setId)) return _clearFinals(setId, null);

    final questions = await questionsFor(setId: setId, leafLabels: const {});
    await _clearFinals(setId, {
      for (final question in questions)
        if (question.isDisliked && !question.isGeneral) question.leafKey,
    });
  }

  /// Closes every community question still open on the Set - general ones
  /// included - as it comes into Community Setup. A Set only gets there a
  /// second time after a send-back, and whatever the community was asked
  /// last time was asked about the recording since redone; the new round
  /// starts empty. Closed, not deleted: the drafter's feedback still reads
  /// them. The website's `TakeComment::closeCommunityRound`.
  static Future<void> closeCommunityRound({required String setId}) async {
    for (final row in await _db.getCollectionRows('take_comments')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;
      if (_str(payload['stage_key']) != 'community_setup') continue;
      if (_str(payload['type']) != 'question') continue;
      if (_str(payload['status']) != 'open') continue;

      await _db.updateRowById(
        table: 'take_comments',
        id: _str(payload['id']),
        update: (question) => {...question, 'status': 'resolved'},
      );
    }
  }

  /// A new back translation answers everything the consultant said about
  /// the old one, so every open consultant comment closes with it.
  static Future<void> resolveBackTranslationComments({
    required String setId,
  }) async {
    for (final comment in await commentsForSet(setId)) {
      if (!comment.isOpen || comment.stageKey != 'consultant') continue;
      await _db.updateRowById(
        table: 'take_comments',
        id: comment.id,
        update: (payload) => {...payload, 'status': 'resolved'},
      );
    }
  }

  /// Withdraws a comment, question or reply - the author's own, which is
  /// the caller's to check ([TakeComment.isMine]).
  ///
  /// One that never left this phone simply goes, along with anything hung
  /// off it. One the server already holds cannot go the same way: a row that
  /// vanishes here says nothing to the server, and the next data load would
  /// bring it straight back. It is closed and hidden instead, which the sync
  /// can carry, so it stops counting everywhere at once.
  static Future<void> deleteComment({
    required String commentId,
    required String setId,
  }) async {
    for (final row in await _db.getCollectionRows('take_comments')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_leafId(payload['parent_id']) != commentId) continue;
      await deleteComment(commentId: _str(payload['id']), setId: setId);
    }

    if (commentId.startsWith('local-')) {
      await _db.deleteRowById(table: 'take_comments', id: commentId);
      return;
    }

    await _db.updateRowById(
      table: 'take_comments',
      id: commentId,
      update: (payload) => {
        ...payload,
        'status': 'resolved',
        DatabaseHelper.deletedFlag: true,
      },
    );
  }

  /// Answers a comment - the back translator replying to the consultant.
  static Future<String> addCommentReply({
    required String setId,
    required TakeComment parent,
    required String stageKey,
    String text = '',
    String? audioFilePath,
  }) async {
    final localId = await _db.insertLocalRow(
      table: 'take_comments',
      payload: {
        'obt_set_id': setId,
        'leaf_type': null,
        'leaf_id': null,
        'parent_id': parent.id,
        'stage_key': stageKey,
        'type': 'reply',
        'text': text,
        'audio_path': audioFilePath ?? '',
        'author_name': 'You',
        'author_id': SessionService.userId?.toString() ?? '',
        'status': 'open',
        'created_at': _serverNow(),
      },
    );
    await ActivityLog.record(
      'reply_added',
      setId: setId,
      details: {'stage': stageKey},
    );
    return localId;
  }

  /// Writes a community-test question during Community Setup.
  ///
  /// A question pinned to a passage carries [leafId] and the [positionSeconds]
  /// in the merged recording where it was added; a general question about the
  /// whole Set carries neither.
  static Future<String> addQuestion({
    required String setId,
    String text = '',
    String? audioFilePath,
    String leafType = '',
    String leafId = '',
    String? takeId,
    double? positionSeconds,
  }) async {
    final localId = await _db.insertLocalRow(
      table: 'take_comments',
      payload: {
        'obt_set_id': setId,
        // Null, not empty, for a general question: the server files an
        // empty leaf id as passage 0.
        'leaf_type': leafType.isEmpty ? null : leafType,
        'leaf_id': leafId.isEmpty ? null : leafId,
        'take_id': (takeId ?? '').isEmpty ? null : takeId,
        'stage_key': 'community_setup',
        'type': 'question',
        'text': text,
        'audio_path': audioFilePath ?? '',
        'position_seconds': positionSeconds,
        'author_name': 'You',
        'author_id': SessionService.userId?.toString() ?? '',
        'status': 'open',
        'created_at': _serverNow(),
      },
    );

    await ActivityLog.record(
      'question_added',
      setId: setId,
      details: {'leaf_id': leafId, 'general': leafId.isEmpty},
    );
    return localId;
  }

  /// Replies to a question during community review.
  ///
  /// Sits alongside the answer rather than replacing it: the answer is what
  /// the community said, the reply is what the reviewer makes of it.
  static Future<String> addReply({
    required String setId,
    required CommunityQuestion question,
    String text = '',
    String? audioFilePath,
  }) async {
    final localId = await _db.insertLocalRow(
      table: 'take_comments',
      payload: {
        'obt_set_id': setId,
        'leaf_type': question.isGeneral ? null : question.leafType,
        'leaf_id': question.leafId,
        'parent_id': question.id,
        'stage_key': 'community_review',
        'type': 'reply',
        'text': text,
        'audio_path': audioFilePath ?? '',
        'author_name': 'You',
        'author_id': SessionService.userId?.toString() ?? '',
        'status': 'open',
        'created_at': _serverNow(),
      },
    );

    return localId;
  }

  /// Answers a community question, by text or by recording.
  ///
  /// A voice answer keeps its WAV on the device the same way a take does, so
  /// answering works with no signal in the room.
  static Future<String> addAnswer({
    required String setId,
    required CommunityQuestion question,
    String text = '',
    String? audioFilePath,
  }) async {
    final localId = await _db.insertLocalRow(
      table: 'take_comments',
      payload: {
        'obt_set_id': setId,
        'leaf_type': question.isGeneral ? null : question.leafType,
        'leaf_id': question.isGeneral ? null : question.leafId,
        'take_id': question.takeId.isEmpty ? null : question.takeId,
        'parent_id': question.id,
        'stage_key': 'community_test',
        'type': 'answer',
        'text': text,
        'audio_path': audioFilePath ?? '',
        'author_name': 'You',
        'author_id': SessionService.userId?.toString() ?? '',
        'status': 'open',
        'created_at': _serverNow(),
      },
    );

    await ActivityLog.record('answer_added', setId: setId);
    return localId;
  }

  /// Clears away the last back-translation round of [setId]: the back
  /// translation itself, what the consultant said about it, and what the
  /// back translator said back. The website's `clearBackTranslationRound`.
  ///
  /// Called whenever the drafter sends a new round forward. All of that was
  /// about the recording as it stood before; a fresh recording needs a
  /// fresh back translation, not the old one waiting to resurface - with
  /// the consultant's objections to it still attached - the next time the
  /// Set reaches the back translator.
  static Future<void> clearBackTranslationRound({required String setId}) async {
    for (final row in await _db.getCollectionRows('take_comments')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;
      if (payload[DatabaseHelper.deletedFlag] == true) continue;

      final stage = _str(payload['stage_key']);
      final type = _str(payload['type']);
      final goes =
          (stage == 'consultant' && type == 'comment') ||
          (stage == 'back_translation' && type == 'reply');
      if (goes) {
        await deleteComment(commentId: _str(payload['id']), setId: setId);
      }
    }

    for (final row in await _db.getCollectionRows('back_translations')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;

      final id = _str(payload['id']);
      if (id.startsWith('local-')) {
        // Never left this phone: it simply goes.
        await _db.deleteRowById(table: 'back_translations', id: id);
        continue;
      }

      // One the server holds cannot be deleted through the sync, and a data
      // load would hand it straight back. Hidden, and kept hidden.
      await _db.updateRowById(
        table: 'back_translations',
        id: id,
        markDirty: false,
        update: (bt) => {
          ...bt,
          DatabaseHelper.deletedFlag: true,
          DatabaseHelper.keepLocalFlag: true,
        },
      );
    }
  }

  /// When the back translation before the current one was written, or
  /// null when the Set has had only one. What the Consultant said since
  /// then is the round that led to the back translation in front of them;
  /// anything older has been answered twice over. The website's
  /// `$previousBT`.
  static Future<String?> previousBackTranslationAt(String setId) async {
    final written = <String>[];
    for (final row in await _db.getCollectionRows('back_translations')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;
      if (payload[DatabaseHelper.deletedFlag] == true) continue;

      final at = _str(payload['created_at']);
      if (at.isNotEmpty) written.add(at);
    }
    if (written.length < 2) return null;

    written.sort((a, b) => _time(a).compareTo(_time(b)));
    return written[written.length - 2];
  }

  /// Whether [moment] is at or after [since], both as the server writes
  /// them.
  static bool isSince(String moment, String since) =>
      !_time(moment).isBefore(_time(since));

  /// The back translation now in force for a Set, if one has been written.
  static Future<BackTranslation?> backTranslationFor(String setId) async {
    for (final row in await _db.getCollectionRows('back_translations')) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final bt = Map<String, dynamic>.from(payload);
      if (_str(bt['obt_set_id']) != setId) continue;
      if (_isFalse(bt['is_current'])) continue;
      if (bt[DatabaseHelper.deletedFlag] == true) continue;

      return BackTranslation(
        id: _str(bt['id']),
        text: _str(bt['text']),
        audioPath: _str(bt['audio_path']),
        isLocal: bt[DatabaseHelper.localFlag] == true,
      );
    }
    return null;
  }

  /// Saves the back translation, superseding any earlier one.
  static Future<String> saveBackTranslation({
    required String setId,
    String text = '',
    String? audioFilePath,
  }) async {
    // Only one is current, so the old row goes rather than lingering behind
    // the new one the way a second local row would.
    for (final row in await _db.getCollectionRows('back_translations')) {
      final payload = row['payload'];
      if (payload is! Map) continue;
      if (_str(payload['obt_set_id']) != setId) continue;
      await _db.deleteRowById(
        table: 'back_translations',
        id: _str(payload['id']),
      );
    }

    final localId = await _db.insertLocalRow(
      table: 'back_translations',
      payload: {
        'obt_set_id': setId,
        'text': text,
        'audio_path': audioFilePath ?? '',
        'is_current': true,
        'created_by': SessionService.userId?.toString() ?? '',
        'created_at': _serverNow(),
      },
    );

    await ActivityLog.record(
      'back_translation_saved',
      setId: setId,
      details: {'has_audio': (audioFilePath ?? '').isNotEmpty},
    );
    return localId;
  }

  /// Moves the Set to the next stage. [from] is what the app believed the
  /// stage was; the server rejects the action outright if that no longer
  /// holds, rather than applying it to the wrong stage.
  static Future<void> transitionSet({
    required String setId,
    required String from,
    required String to,

    /// Whether this is a Set going back rather than on. The stage it came
    /// from is stored with it, so the screen that receives it can say who
    /// returned it instead of leaving somebody to work that out.
    bool sentBack = false,
  }) async {
    await _db.updateRowById(
      table: 'sets',
      id: setId,
      update: (payload) => {
        ...payload,
        // What the stage was before this device first touched it. Kept from
        // the first move only: a drafter can take a Set through three stages
        // in one afternoon offline, and it is the stage the SERVER last knew
        // that a send has to compare against.
        DatabaseHelper.fromStatusFlag:
            payload[DatabaseHelper.fromStatusFlag] ?? from,
        'workflow_status': to,
        // Stamped here rather than left to the server: this is when the
        // person actually handed the Set on, and that can be hours before
        // the phone finds a signal to say so. `updated_at` is the row's own
        // business and is left alone.
        'workflow_updated_at': _serverNow(),
        // Cleared when the Set moves forward: it describes the trip it is on
        // now, not every trip it has ever made.
        'redo_from_stage': sentBack ? from : null,
      },
    );
  }

  /// Builds one question from a stored row, for tests of the rules that
  /// decide what a row means - otherwise reachable only through the database.
  @visibleForTesting
  static CommunityQuestion debugQuestionFromRow(Map<String, dynamic> row) =>
      CommunityQuestion(
        id: _str(row['id']),
        text: _str(row['text']),
        audioPath: _str(row['audio_path']),
        leafType: _str(row['leaf_type']),
        leafId: _leafId(row['leaf_id']),
        leafLabel: _str(row['leaf_label']),
        positionSeconds: double.tryParse(_str(row['position_seconds'])),
        createdAt: _str(row['created_at']),
        answer: null,
        replies: const [],
        isLocal: row[DatabaseHelper.localFlag] == true,
      );

  /// A leaf id, or empty when the row names no passage.
  ///
  /// A general question is stored here with no leaf, but "no leaf" comes
  /// back from the server in more than one shape - an absent field, a null,
  /// or a zero standing in for one. Read literally, a zero is an id like any
  /// other, and the question stops looking general: it gets a passage pill
  /// and a pin on a passage that does not exist.
  static String _leafId(Object? value) {
    final text = _str(value);
    if (text.isEmpty || text == '0' || text.toLowerCase() == 'null') return '';
    return text;
  }

  static String _str(Object? value) => value?.toString().trim() ?? '';

  /// A flag the server has switched off. Eloquent casts `is_current` and
  /// `is_active` to JSON booleans; older rows and rows written here may
  /// still carry `0`/`1`, so both shapes are read.
  static bool _isFalse(Object? value) {
    if (value == false || value == 0) return true;
    final text = _str(value).toLowerCase();
    return text == '0' || text == 'false';
  }
}
