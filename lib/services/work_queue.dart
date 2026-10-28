import 'package:flutter/material.dart';
import 'package:get/get.dart' show Trans;
import 'package:livuka/Audio/audio_cache.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/vault.dart';
import 'package:livuka/services/name_language.dart';
import 'package:livuka/services/take_repository.dart';

/// Dart port of the Laravel `App\Support\WorkQueue` dashboard logic, driven by
/// the collected data in sqflite instead of an HTTP call.
///
/// Work tiles are per-STAGE, not per-role: a role like `drafter` covers Draft,
/// Sent back, Community Setup and Community Test, and someone with 10 Drafts
/// and 1 Sent-back needs to see both counts rather than one lumped tile.
class WorkQueue {
  WorkQueue._();

  /// Role keys this app supports, matching the Laravel `role_key` values.
  static const List<String> supportedRoles = [
    'drafter',
    'peer',
    'back_translator',
    'consultant',
  ];

  /// Keyed by `workflow_status`, which is already unique across roles, and
  /// ordered the way work flows through the pipeline.
  static const List<StageMeta> stageMeta = [
    StageMeta(
      status: 'redo',
      role: 'drafter',
      label: 'Sent back',
      icon: Icons.rotate_left,
      color: Color(0xFFDC2626),
      configurable: false,
    ),
    // A Set with no take yet, and one with at least one: the website keeps
    // them apart so the workbench can say which is which. Both are the
    // drafter's, and one tile holds them - split, a drafter with ten Sets
    // to begin and one half done would be told to look in two places for
    // the same job.
    StageMeta(
      status: 'not_started',
      role: 'drafter',
      label: 'Draft',
      icon: Icons.mic_none,
      color: Color(0xFFCD572D),
      configurable: false,
      tileWith: 'recorded',
    ),
    StageMeta(
      status: 'recorded',
      role: 'drafter',
      label: 'Draft',
      icon: Icons.mic_none,
      color: Color(0xFFCD572D),
      configurable: false,
    ),
    StageMeta(
      status: 'community_setup',
      role: 'drafter',
      label: 'Community Setup',
      icon: Icons.help_outline,
      color: Color(0xFF0E7C66),
    ),
    StageMeta(
      status: 'community_test',
      role: 'drafter',
      label: 'Community Test',
      icon: Icons.groups_outlined,
      color: Color(0xFF2563EB),
    ),
    StageMeta(
      status: 'peer',
      role: 'peer',
      label: 'Peer Check',
      icon: Icons.headphones_outlined,
      color: Color(0xFF2F6FA8),
    ),
    StageMeta(
      status: 'community_review',
      role: 'peer',
      label: 'Community Review',
      icon: Icons.thumb_up_alt_outlined,
      color: Color(0xFFDB2777),
    ),
    StageMeta(
      status: 'back_translation',
      role: 'back_translator',
      label: 'Back Translation',
      icon: Icons.translate,
      color: Color(0xFFFBBF24),
    ),
    StageMeta(
      status: 'consultant',
      role: 'consultant',
      label: 'Consultant Check',
      icon: Icons.how_to_reg_outlined,
      color: Color(0xFF15803D),
    ),
  ];

  /// Approved Sets. Not a tile - the app has no Approved section - but the
  /// status still needs its name wherever a Set's stage is written out
  /// (the sync status screen, a send that found the Set moved on).
  static const StageMeta finishedStage = StageMeta(
    status: 'approved',
    role: 'drafter',
    label: 'Approved',
    // A fixed tag beside the icon, in the tile's own colour: "Approved,
    // already CC checked", the way the website's tile reads.
    badge: 'CC Checked',
    icon: Icons.check_circle_outline,
    color: Color(0xFF475569),
    configurable: false,
  );

  /// Liked answers that came with a comment. Not a stage - nothing is
  /// waiting on it - so it sits outside [stageMeta] like Finished does.
  static const StageMeta feedbackStage = StageMeta(
    status: 'feedback',
    role: 'drafter',
    label: 'Feedback',
    icon: Icons.forum_outlined,
    color: Color(0xFF0891B2),
    configurable: false,
  );

  /// The statuses a tile stands for: its own, and any that share it. A Set
  /// already begun sits under "New Draft" with the untouched ones, not on a
  /// tile of its own.
  static Set<String> statusesOf(StageMeta meta) => {
    meta.status,
    for (final other in stageMeta)
      if (other.tileWith == meta.status) other.status,
  };

  static StageMeta? metaForStatus(String status) {
    for (final stage in [...stageMeta, finishedStage, feedbackStage]) {
      if (stage.status == status) return stage;
    }
    return null;
  }

  /// What the person holding [role] can do with a Set sitting at [status].
  ///
  /// This mirrors the web app's transition map: a Set only moves to a stage
  /// the role holding it is allowed to hand it to. Anything missing here is
  /// simply not offered.
  static List<StageAction> actionsFor({
    required String role,
    required String status,

    /// The stage that sent this Set back, when one did. A Set returned by
    /// the back translator goes straight back to them once the drafter has
    /// fixed it - the stages in between already passed it, and sending it
    /// round them a second time asks people to check work they have checked.
    String redoFromStage = '',
  }) {
    if (role == 'drafter' &&
        status == 'redo' &&
        redoFromStage == 'back_translation') {
      return const [
        StageAction(
          label: 'Send to the Back Translator',
          toStatus: 'back_translation',
          confirmMessage: 'Send this Set to the Back Translator?',
          requiresAllFinal: true,
        ),
      ];
    }

    return switch ((role, status)) {
      ('drafter', 'not_started') ||
      ('drafter', 'recorded') ||
      ('drafter', 'redo') => const [
        StageAction(
          label: 'Send to Peer Check',
          toStatus: 'peer',
          confirmMessage: 'Send this Set to Peer Check?',
          requiresAllFinal: true,
        ),
      ],
      ('peer', 'peer') => const [
        StageAction.sendBackToDrafter(),
        StageAction(
          label: 'Send to Community Setup',
          toStatus: 'community_setup',
          confirmMessage: 'Send this Set to Community Setup?',
        ),
      ],
      ('drafter', 'community_setup') => const [
        StageAction(
          label: 'Send to Community Test',
          toStatus: 'community_test',
          confirmMessage: 'Send this Set to Community Test?',
        ),
      ],
      ('drafter', 'community_test') => const [
        StageAction(
          label: 'Send to Community Review',
          toStatus: 'community_review',
          confirmMessage: 'Send this Set to Community Review?',
        ),
      ],
      ('peer', 'community_review') => const [
        StageAction.sendBackToDrafter(),
        StageAction(
          label: 'Send to Back Translation',
          toStatus: 'back_translation',
          confirmMessage: 'Send this Set to Back Translation?',
        ),
      ],
      ('back_translator', 'back_translation') => const [
        StageAction.sendBackToDrafter(),
        StageAction(
          label: 'Submit to Consultant',
          toStatus: 'consultant',
          confirmMessage: 'Submit this back translation to the Consultant?',
          confirmLabel: 'Submit',
        ),
      ],
      ('consultant', 'consultant') => const [
        StageAction(
          label: 'Send back to the Back Translator',
          toStatus: 'back_translation',
          confirmMessage: 'Send this Set back to the Back Translator?',
          confirmLabel: 'Send back',
          isSendBack: true,
        ),
        StageAction(
          label: 'Approve',
          toStatus: 'approved',
          confirmMessage: 'Approve this Set? It will be marked finished.',
          confirmLabel: 'Approve',
        ),
      ],
      _ => const [],
    };
  }

  /// Colour per role, mirroring the palette the Laravel dashboard uses.
  /// What a role is called in plain words - `back_translator` is a column
  /// value, not something to show somebody.
  static String labelForRole(String role) {
    return switch (role) {
      'drafter' => 'Drafter',
      'peer' => 'Peer checker',
      'back_translator' => 'Back translator',
      'consultant' => 'Consultant',
      _ => role.replaceAll('_', ' '),
    };
  }

  /// A role wears the colour and icon of the stage it works at, as on the
  /// pipeline diagram: the drafter is Draft's teal and microphone, the peer
  /// Peer Check's indigo and headphones, and so on. One picture of each
  /// role across the whole app, and the same one as in the manual.
  static ({Color fg, Color bg, IconData icon}) badgeForRole(String role) {
    final stage = switch (role) {
      'drafter' => metaForStatus('recorded'),
      'peer' => metaForStatus('peer'),
      'back_translator' => metaForStatus('back_translation'),
      'consultant' => metaForStatus('consultant'),
      _ => null,
    };
    if (stage == null) {
      return (
        fg: const Color(0xFF4B4870),
        bg: const Color(0xFFF1F2F4),
        icon: Icons.person_outline,
      );
    }
    return (
      fg: stage.color,
      bg: stage.color.withValues(alpha: 0.13),
      icon: stage.icon,
    );
  }

  static Color colorForRole(String role) => badgeForRole(role).fg;

  /// One entry per stage that has at least one Set waiting, in pipeline order.
  ///
  /// Counts come from the user's own `SetAssigned` rows joined to `sets` on
  /// `obt_set_id`, so a Set only counts for a stage when the signed-in user is
  /// actually assigned to the role that owns that stage.
  /// The `step_key`s an admin has left switched on.
  ///
  /// Empty when the table has not synced, which is treated as "no opinion" -
  /// hiding every stage because a table is missing would empty the workbench
  /// rather than reflect a decision anyone made.
  /// What a stage is called, given the status a row holds. Empty for a
  /// status no stage answers to, so an unknown value stays quiet rather than
  /// being shown to somebody as a label.
  static String labelForStatus(String status) {
    if (status.isEmpty) return '';

    for (final stage in stageMeta) {
      if (stage.status == status) return stage.label;
    }
    if (status == finishedStage.status) return finishedStage.label;

    return '';
  }

  static Future<Set<String>> activeStepKeys() async {
    final rows = await DatabaseHelper.instance.getCollectionRows(
      'workflow_steps',
    );

    return {
      for (final row in rows)
        if (row['payload'] case final Map payload)
          if (!const {
            '0',
            'false',
          }.contains(_asString(payload['is_active']).toLowerCase()))
            _asString(payload['step_key']),
    }..removeWhere((key) => key.isEmpty);
  }

  /// Every tile of the workbench: the stages, and the feedback tile after
  /// them.
  static Future<List<WorkStage>> pendingCounts() async {
    final stages = await stageCounts();
    final praised = await feedbackStageCount();
    return [...stages, ?praised];
  }

  /// The feedback tile, or null when there is nothing to read. Apart from
  /// the stages because it is the slow one: it follows every question of
  /// every Set to its answer, where a stage is a count.
  static Future<WorkStage?> feedbackStageCount() async {
    final praised = await feedbackSets();
    if (praised.isEmpty) return null;
    return WorkStage(meta: feedbackStage, count: praised.length);
  }

  /// The stage tiles alone - two tables read once each, so the numbers are
  /// right the moment the workbench is back on screen.
  static Future<List<WorkStage>> stageCounts() async {
    final helper = DatabaseHelper.instance;
    final steps = await activeStepKeys();

    final setsById = _activeSetsById(await helper.getCollectionRows('sets'));
    final assignments = _uniqueAssignments(
      await helper.getCollectionRows('set_assignment'),
    );

    final stages = <WorkStage>[];

    for (final meta in stageMeta) {
      // Counted under another tile, not its own.
      if (meta.tileWith != null) continue;

      // A stage switched off for this project is not part of the pipeline,
      // so it gets no tile even if a Set is somehow sitting at it.
      if (meta.configurable &&
          steps.isNotEmpty &&
          !steps.contains(meta.status)) {
        continue;
      }

      var count = 0;
      DateTime? newest;

      for (final assignment in assignments) {
        if (assignment.roleKey != meta.role) continue;

        final set = setsById[assignment.setId];
        if (set == null) continue;
        if (!statusesOf(meta).contains(_asString(set['workflow_status']))) {
          continue;
        }

        count++;

        // Sent back wears when a Set was LAST sent back: the tile is where
        // news of a send-back arrives, and with the oldest Set's age on it
        // one returned four minutes ago read "1 hour ago" - as though
        // nothing had come. workflow_updated_at is stamped on every
        // hand-off, so while a Set sits at redo it is exactly when it was
        // sent back.
        if (meta.status == 'redo') {
          final at = _serverTime(_asString(set['workflow_updated_at']));
          if (at != null && (newest == null || at.isAfter(newest))) {
            newest = at;
          }
        }
      }

      if (count > 0) {
        stages.add(WorkStage(meta: meta, count: count, waitingSince: newest));
      }
    }

    return stages;
  }

  /// The Sets this user drafted that carry feedback: liked answers with a
  /// comment, on passage questions, whose recording is still the current
  /// one. Whatever stage the Set has reached - praise given at community
  /// review is still worth reading once the Set is with the consultant.
  static Future<List<FeedbackSet>> feedbackSets() async {
    final helper = DatabaseHelper.instance;

    final setsById = _activeSetsById(await helper.getCollectionRows('sets'));
    final assignments = _uniqueAssignments(
      await helper.getCollectionRows('set_assignment'),
    );
    final linksById = _byId(await helper.getCollectionRows('book_links'));

    // Feedback is a verdict on an answer, and a verdict is a reply. A Set
    // with no reply in it has none to show, and is not read any further:
    // following the questions of every Set the drafter holds, each by
    // reading the whole table again, is what kept the workbench's numbers
    // stale for seconds after coming back to it.
    final withReplies = <String>{
      for (final row in await helper.getCollectionRows('take_comments'))
        if (row['payload'] case final Map payload)
          if (_asString(payload['type']) == 'reply')
            _asString(payload['obt_set_id']),
    };

    final result = <FeedbackSet>[];

    for (final assignment in assignments) {
      if (assignment.roleKey != 'drafter') continue;
      if (!withReplies.contains(assignment.setId)) continue;

      final set = setsById[assignment.setId];
      if (set == null) continue;

      final feedback = await TakeRepository.feedbackFor(
        setId: assignment.setId,
        leafLabels: const {},
      );
      if (feedback.isEmpty) continue;

      final link = linksById[_asString(set['book_link_id'])];
      result.add(
        FeedbackSet(
          count: feedback.length,
          set: WorkSet(
            id: assignment.setId,
            name: _asString(set['name']),
            slName: assignment.slName.isNotEmpty
                ? assignment.slName
                : _asString(set['sl_name']),
            sortOrder: int.tryParse(_asString(set['sort_order'])) ?? 0,
            workflowStatus: _asString(set['workflow_status']),
            workflowUpdatedAt: _asString(set['workflow_updated_at']),
            roleKey: 'drafter',
            bookName: _asString(link?['book_name']),
            languageName: _asString(link?['language_name']),
          ),
        ),
      );
    }

    result.sort((a, b) => a.set.sortOrder.compareTo(b.set.sortOrder));
    return result;
  }

  /// Every Set the user is assigned to for [role] that currently sits at
  /// [status], in Set order — the Laravel `setsForRole` query filtered to one
  /// stage, which is what tapping a dashboard tile opens.
  static Future<List<WorkSet>> setsForStage({
    required String status,
    required String role,
  }) async {
    final helper = DatabaseHelper.instance;

    final setsById = _activeSetsById(await helper.getCollectionRows('sets'));
    final assignments = _uniqueAssignments(
      await helper.getCollectionRows('set_assignment'),
    );
    final linksById = _byId(await helper.getCollectionRows('book_links'));

    final result = <WorkSet>[];

    final meta = metaForStatus(status);
    final wanted = meta == null ? {status} : statusesOf(meta);

    for (final assignment in assignments) {
      if (assignment.roleKey != role) continue;

      final set = setsById[assignment.setId];
      if (set == null) continue;
      final setStatus = _asString(set['workflow_status']);
      if (!wanted.contains(setStatus)) continue;

      final link = linksById[_asString(set['book_link_id'])];

      result.add(
        WorkSet(
          id: assignment.setId,
          name: _asString(set['name']),
          // Off the assignment first, which is where the server sends it;
          // the Set row is read as a fallback in case it lands there too.
          slName: assignment.slName.isNotEmpty
              ? assignment.slName
              : _asString(set['sl_name']),
          sortOrder: int.tryParse(_asString(set['sort_order'])) ?? 0,
          workflowStatus: setStatus,
          redoFromStage: _asString(set['redo_from_stage']),
          workflowUpdatedAt: _asString(set['workflow_updated_at']),
          roleKey: role,
          bookName: _asString(link?['book_name']),
          languageName: _asString(link?['language_name']),
        ),
      );
    }

    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return result;
  }

  /// How many passages of each Set already have a final take.
  ///
  /// One pass over the tables for every Set asked about, rather than loading
  /// each Set's leaves in turn: the queue lists them all at once and only
  /// needs the two numbers.
  static Future<Map<String, ({int done, int total})>> recordedProgress(
    Iterable<String> setIds,
  ) async {
    final helper = DatabaseHelper.instance;
    final wanted = setIds.toSet();
    if (wanted.isEmpty) return const {};

    // A final take that was thrown away leaves its passage unrecorded again.
    final liveTakes = <String>{};
    for (final row in await helper.getCollectionRows('takes')) {
      final take = _payload(row);
      if (take == null) continue;
      if (_asString(take['status']) == 'trashed') continue;

      final id = _asString(take['id']);
      if (id.isNotEmpty) liveTakes.add(id);
    }

    final finalLeaves = <String>{};
    for (final row in await helper.getCollectionRows('final_takes')) {
      final finalTake = _payload(row);
      if (finalTake == null) continue;
      if (!liveTakes.contains(_asString(finalTake['take_id']))) continue;

      finalLeaves.add(
        '${_asString(finalTake['leaf_type'])}|'
        '${_asString(finalTake['leaf_id'])}',
      );
    }

    final progress = <String, ({int done, int total})>{
      for (final id in wanted) id: (done: 0, total: 0),
    };
    // Leaves, not passages: a divided passage is finished when each of its
    // sub-passages is, and counts as that many things to record.
    for (final setId in wanted) {
      final leaves = await _orderedLeafRows(setId);
      progress[setId] = (
        done: leaves.where((l) => finalLeaves.contains(l.storeKey)).length,
        total: leaves.length,
      );
    }

    return progress;
  }

  /// The languages this user has work in, from the Sets assigned to them.
  ///
  /// Read from the assignments rather than stored on the account: a person is
  /// given Sets, and the language follows from the book each Set belongs to.
  static Future<List<String>> assignedLanguages() async {
    final helper = DatabaseHelper.instance;

    final setsById = _activeSetsById(await helper.getCollectionRows('sets'));
    final linksById = _byId(await helper.getCollectionRows('book_links'));
    final assignments = _uniqueAssignments(
      await helper.getCollectionRows('set_assignment'),
    );

    final languages = <String>{};

    for (final assignment in assignments) {
      final set = setsById[assignment.setId];
      if (set == null) continue;

      final link = linksById[_asString(set['book_link_id'])];
      final language = _asString(link?['language_name']);
      if (language.isNotEmpty) languages.add(language);
    }

    final sorted = languages.toList()..sort();
    return sorted;
  }

  /// One row per passage in a Set, carrying its take count and whichever take
  /// is marked Final — the shape every work screen builds on.
  static Future<List<SetLeaf>> leavesForSet(String setId) async {
    final helper = DatabaseHelper.instance;

    // Every Set screen starts here, while its loading shimmer is up: the
    // Set's recordings and scripts are turned back from the vault now, so
    // the screen finds them plain. Nothing for a Set already turned back.
    await Vault.unlockFor(setId);

    final takesById = <String, Map<String, dynamic>>{};
    final takeCountByLeaf = <String, int>{};

    for (final row in await helper.getCollectionRows('takes')) {
      final take = _payload(row);
      if (take == null) continue;
      if (_asString(take['obt_set_id']) != setId) continue;
      // Thrown away by the drafter: it is kept for the sync to report, but
      // it is not a take of this passage any more, so it counts for nothing
      // and can never resolve as the final one.
      if (_asString(take['status']) == 'trashed') continue;

      final id = _asString(take['id']);
      if (id.isEmpty || takesById.containsKey(id)) continue;
      takesById[id] = take;

      final key =
          '${_asString(take['leaf_type'])}|${_asString(take['leaf_id'])}';
      takeCountByLeaf[key] = (takeCountByLeaf[key] ?? 0) + 1;
    }

    // final_takes points at a take id, so the audio path has to be resolved
    // through the takes above rather than read off the row directly.
    final finalTakeByLeaf = <String, Map<String, dynamic>>{};
    for (final row in await helper.getCollectionRows('final_takes')) {
      final finalTake = _payload(row);
      if (finalTake == null) continue;

      final take = takesById[_asString(finalTake['take_id'])];
      if (take == null) continue;

      final key =
          '${_asString(finalTake['leaf_type'])}|${_asString(finalTake['leaf_id'])}';
      finalTakeByLeaf.putIfAbsent(key, () => take);
    }

    final openMarksByLeaf = <String, int>{};
    final faultedTakes = <String>{};
    for (final row in await helper.getCollectionRows('take_comments')) {
      final comment = _payload(row);
      if (comment == null) continue;
      if (_asString(comment['obt_set_id']) != setId) continue;
      if (_asString(comment['status']) != 'open') continue;
      if (comment[DatabaseHelper.deletedFlag] == true) continue;

      final type = _asString(comment['type']);
      if (type != 'comment' && type != 'reply') continue;

      final faulted = _asString(comment['take_id']);
      if (faulted.isNotEmpty && faulted != '0') faultedTakes.add(faulted);
      // A reply is a Community Review Dislike, and counts against its
      // passage as a comment does - the website's `$openMarks`.
      if (type == 'reply' && _asString(comment['reaction']) == 'like') {
        continue;
      }

      final key =
          '${_asString(comment['leaf_type'])}|${_asString(comment['leaf_id'])}';
      openMarksByLeaf[key] = (openMarksByLeaf[key] ?? 0) + 1;
    }

    // A take with an open comment against it can never be the final one:
    // the comment is about that very recording, and only a new take answers
    // it. Sending a Set back clears these on the way, but a data load can
    // hand the old choice back, so the rule is applied where finals are read
    // rather than trusted to have been applied where they were written.
    //
    // Only while the drafter holds the Set. To the reviewer who wrote the
    // comment, the take it is on is still the recording they are checking.
    final holder = _activeSetsById(
      await helper.getCollectionRows('sets'),
    )[setId];
    final status = _asString(holder?['workflow_status']);
    if (status == 'redo' || status == 'recorded' || status == 'not_started') {
      finalTakeByLeaf.removeWhere(
        (_, take) => faultedTakes.contains(_asString(take['id'])),
      );
    }

    return [
      for (final row in await _orderedLeafRows(setId))
        _leafFrom(
          row,
          takesCount: takeCountByLeaf[row.storeKey] ?? 0,
          finalTake: finalTakeByLeaf[row.storeKey],
          openMarks: openMarksByLeaf[row.storeKey] ?? 0,
        ),
    ];
  }

  /// The things in a Set that are actually recorded, in reading order - the
  /// website's `SetLeaves::ordered`.
  ///
  /// A passage that has been divided is not itself recorded: its
  /// sub-passages are, in its place and in their own order, each named
  /// "Passage - Sub passage". A passage with none is its own leaf. Both are
  /// ordered by `sort_order` and then by id, because equal or unset sort
  /// orders would otherwise come back in whatever order the table held them,
  /// and the merged recording would play out of sequence.
  static Future<List<_LeafRow>> _orderedLeafRows(String setId) async {
    final helper = DatabaseHelper.instance;

    int order(Map<String, dynamic> row) =>
        int.tryParse(_asString(row['sort_order'])) ?? 0;
    int idOf(Map<String, dynamic> row) =>
        int.tryParse(_asString(row['id'])) ?? 0;
    int byOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
      final bySort = order(a).compareTo(order(b));
      return bySort != 0 ? bySort : idOf(a).compareTo(idOf(b));
    }

    final passages = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final row in await helper.getCollectionRows('passages')) {
      final passage = _payload(row);
      if (passage == null) continue;
      if (_asString(passage['obt_set_id']) != setId) continue;
      if (_asString(passage['status']) != 'active') continue;

      final id = _asString(passage['id']);
      if (id.isEmpty || !seen.add(id)) continue;
      passages.add(passage);
    }
    passages.sort(byOrder);

    final subsByPassage = <String, List<Map<String, dynamic>>>{};
    final seenSubs = <String>{};
    for (final row in await helper.getCollectionRows('sub_passages')) {
      final sub = _payload(row);
      if (sub == null) continue;
      if (_asString(sub['status']) != 'active') continue;

      final parent = _asString(sub['obt_passage_id']);
      if (!seen.contains(parent)) continue;

      final id = _asString(sub['id']);
      if (id.isEmpty || !seenSubs.add(id)) continue;
      subsByPassage.putIfAbsent(parent, () => []).add(sub);
    }

    final rows = <_LeafRow>[];
    for (final passage in passages) {
      final subs = subsByPassage[_asString(passage['id'])] ?? const [];
      if (subs.isEmpty) {
        rows.add(
          _LeafRow(
            type: 'passage',
            row: passage,
            label: _asString(passage['name']),
            position: rows.length,
          ),
        );
        continue;
      }

      for (final sub in [...subs]..sort(byOrder)) {
        rows.add(
          _LeafRow(
            type: 'sub_passage',
            row: sub,
            label: '${_asString(passage['name'])} - ${_asString(sub['name'])}',
            position: rows.length,
          ),
        );
      }
    }

    return rows;
  }

  static SetLeaf _leafFrom(
    _LeafRow leaf, {
    required int takesCount,
    required Map<String, dynamic>? finalTake,
    required int openMarks,
  }) {
    final row = leaf.row;

    return SetLeaf(
      type: leaf.type,
      id: _asString(row['id']),
      label: leaf.label,
      verseRange: _asString(row['verse_range']),
      // Its place in the Set, not the row's own `sort_order`: a sub-passage
      // is numbered within its passage, and two of them from different
      // passages can both be "1".
      sortOrder: leaf.position,
      sourceScript: _asString(row['source_script']),
      targetScript: _asString(row['target_script']),
      sourceScriptFromFile: _fromFile(row, 'source_script'),
      targetScriptFromFile: _fromFile(row, 'target_script'),
      sourceAudioPath: _asString(row['source_audio_path']),
      takesCount: takesCount,
      finalTake: finalTake,
      openMarks: openMarks,
    );
  }

  /// Whether a script column named a `.txt` file.
  ///
  /// Only a file is the passage. A line typed straight into the column is a
  /// description of it, and showing that where the script belongs tells the
  /// reader the passage says something it does not.
  ///
  /// The answer is stamped on the row as it is cached, because by then the
  /// column holds the fetched text and a typed line looks no different.
  static bool _fromFile(Map<String, dynamic> row, String column) {
    final flag = AudioCacheService.scriptFileFlag(column);
    if (row.containsKey(flag)) return row[flag] == true;

    // No stamp: this row was cached before there was one. The text is
    // already here and refusing to show it would blank a script the phone
    // holds, so the two are told apart by what they are. A passage runs to
    // several verses and carries line breaks; a description of one is a
    // short single line. A value still holding its path was never fetched
    // and there is nothing to show either way.
    final value = _asString(row[column]);
    if (value.isEmpty) return false;
    if (AudioCacheService.isScriptFile(value)) return false;

    return value.contains('\n') || value.length > _shortestScript;
  }

  /// Longer than any label somebody would type into a script column, and
  /// shorter than any passage worth reading aloud.
  static const int _shortestScript = 120;

  /// Builds a leaf from one stored passage row, for tests of the rules that
  /// decide what a row means - which is otherwise reachable only through the
  /// database.
  @visibleForTesting
  static SetLeaf debugLeafFromRow(Map<String, dynamic> passage) => SetLeaf(
    type: 'passage',
    id: _asString(passage['id']),
    label: _asString(passage['name']),
    verseRange: _asString(passage['verse_range']),
    sortOrder: 0,
    sourceScript: _asString(passage['source_script']),
    targetScript: _asString(passage['target_script']),
    sourceScriptFromFile: _fromFile(passage, 'source_script'),
    targetScriptFromFile: _fromFile(passage, 'target_script'),
    sourceAudioPath: _asString(passage['source_audio_path']),
    takesCount: 0,
    finalTake: null,
    openMarks: 0,
  );

  static Map<String, Map<String, dynamic>> _byId(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final data = _payload(row);
      if (data == null) continue;

      final id = _asString(data['id']);
      if (id.isEmpty || result.containsKey(id)) continue;
      result[id] = data;
    }
    return result;
  }

  static Map<String, dynamic>? _payload(Map<String, dynamic> row) {
    final payload = row['payload'];
    return payload is Map ? Map<String, dynamic>.from(payload) : null;
  }

  /// Active sets keyed by id. Rows arrive newest-first, so the first entry for
  /// an id wins if an older data load left duplicates behind.
  static Map<String, Map<String, dynamic>> _activeSetsById(
    List<Map<String, dynamic>> rows,
  ) {
    final result = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final set = Map<String, dynamic>.from(payload);
      final id = _asString(set['id']);
      if (id.isEmpty || result.containsKey(id)) continue;
      if (_asString(set['status']) != 'active') continue;

      result[id] = set;
    }

    return result;
  }

  /// One assignment per (set, role) pair, newest first, so repeated data loads
  /// cannot inflate the counts.
  static List<_Assignment> _uniqueAssignments(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    final result = <_Assignment>[];

    for (final row in rows) {
      final payload = row['payload'];
      if (payload is! Map) continue;

      final data = Map<String, dynamic>.from(payload);
      final setId = _asString(data['obt_set_id']);
      final roleKey = _asString(data['role_key']);
      if (setId.isEmpty || roleKey.isEmpty) continue;
      if (!supportedRoles.contains(roleKey)) continue;

      if (seen.add('$setId|$roleKey')) {
        result.add(
          _Assignment(
            setId: setId,
            roleKey: roleKey,
            slName: _asString(data['sl_name']),
          ),
        );
      }
    }

    return result;
  }

  static String _asString(Object? value) => value?.toString().trim() ?? '';

  /// A server timestamp as a moment. Zoneless ones are UTC - the shape the
  /// phone writes and MySQL holds - while the API's carry a `Z`.
  static DateTime? _serverTime(String value) {
    if (value.isEmpty) return null;
    final zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
    return DateTime.tryParse(
          zoned ? value : '${value.replaceFirst(' ', 'T')}Z',
        ) ??
        DateTime.tryParse(value);
  }

  /// "26 minutes ago", the way the website's tile says it.
  static String timeAgo(DateTime moment) {
    final gap = DateTime.now().toUtc().difference(moment.toUtc());
    if (gap.inSeconds < 60) return 'just now'.tr;

    String say(int n, String one, String many) =>
        (n == 1 ? one : many).trParams({'count': '$n'});

    if (gap.inMinutes < 60) {
      return say(gap.inMinutes, '@count minute ago', '@count minutes ago');
    }
    if (gap.inHours < 24) {
      return say(gap.inHours, '@count hour ago', '@count hours ago');
    }
    if (gap.inDays < 7) {
      return say(gap.inDays, '@count day ago', '@count days ago');
    }
    if (gap.inDays < 30) {
      return say(gap.inDays ~/ 7, '@count week ago', '@count weeks ago');
    }
    if (gap.inDays < 365) {
      return say(gap.inDays ~/ 30, '@count month ago', '@count months ago');
    }
    return say(gap.inDays ~/ 365, '@count year ago', '@count years ago');
  }
}

class StageMeta {
  const StageMeta({
    required this.status,
    required this.role,
    required this.label,
    required this.icon,
    required this.color,
    this.configurable = true,
    this.badge,
    this.tileWith,
  });

  /// Another status this one is counted under on the workbench, so the two
  /// share a tile. Opening the tile lists Sets at either.
  final String? tileWith;

  /// A small fixed label on the tile, when the stage has one.
  final String? badge;

  final String status;
  final String role;
  final String label;
  final IconData icon;

  /// Each stage has its own colour, the same one the website gives it. They
  /// used to be coloured by role, which painted five of the drafter's stages
  /// the same teal and left the tiles telling nobody anything.
  final Color color;

  /// Whether an admin can switch this stage off in `workflow_steps`.
  ///
  /// The six review stages are rows in that table. Draft, Sent back and
  /// Finished are not - they are states a Set passes through rather than
  /// steps in the pipeline, so they are always shown.
  final bool configurable;
}

/// One button on a Set screen: a stage transition the current holder can make.
class StageAction {
  const StageAction({
    required this.label,
    required this.toStatus,
    required this.confirmMessage,
    this.confirmLabel = 'Send',
    this.requiresAllFinal = false,
    this.isSendBack = false,
  });

  /// The three reviewing stages that return a Set to its drafter all ask the
  /// same question in the same words.
  const StageAction.sendBackToDrafter()
    : label = 'Send back to the Drafter',
      toStatus = 'redo',
      confirmMessage = 'Send this Set back to the Drafter?',
      confirmLabel = 'Send back',
      requiresAllFinal = false,
      isSendBack = true;

  final String label;
  final String toStatus;

  /// Every hand-off asks first, in the words the website uses. They live
  /// with the action so that no screen can move a Set without them - and so
  /// the wording is one list to check rather than six screens to read.
  final String confirmMessage;
  final String confirmLabel;

  /// Only the drafter's hand-off is gated on every passage having a final
  /// take — a reviewer sending work back does not need a complete Set.
  final bool requiresAllFinal;

  /// Sends the Set backwards. Rendered as a warning rather than a next step,
  /// and asks for a reason so the receiving role knows what to change.
  final bool isSendBack;
}

/// One recordable thing in a Set, as its table row, before the takes and
/// marks that belong to it have been looked up.
class _LeafRow {
  const _LeafRow({
    required this.type,
    required this.row,
    required this.label,
    required this.position,
  });

  final String type;
  final Map<String, dynamic> row;
  final String label;
  final int position;

  /// How takes, final takes and comments name this leaf in their own rows.
  String get storeKey => '$type|${row['id']?.toString().trim() ?? ''}';
}

/// A Set with praise on it, and how much.
class FeedbackSet {
  const FeedbackSet({required this.set, required this.count});

  final WorkSet set;
  final int count;
}

class WorkStage {
  const WorkStage({required this.meta, required this.count, this.waitingSince});

  final StageMeta meta;
  final int count;

  /// When the longest-waiting Set here was handed over, for the tile to
  /// say how long that has been.
  final DateTime? waitingSince;

  String get label => meta.label;
  IconData get icon => meta.icon;
  Color get color => meta.color;
  String get countLabel =>
      (count == 1 ? '@count Set' : '@count Sets').trParams({'count': '$count'});
}

class _Assignment {
  const _Assignment({
    required this.setId,
    required this.roleKey,
    this.slName = '',
  });

  final String setId;
  final String roleKey;

  /// The Set's name in the source language, as the assignment row carries it.
  final String slName;
}

/// One Set in a role's queue, with the plain-language progress label the
/// Laravel `WorkQueue::queueInfo` produces for the same (role, status) pair.
class WorkSet {
  const WorkSet({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.workflowStatus,
    required this.roleKey,
    required this.bookName,
    required this.languageName,
    this.slName = '',
    this.redoFromStage = '',
    this.workflowUpdatedAt = '',
  });

  final String id;
  final String name;
  final int sortOrder;

  /// When the Set last changed hands. Every hand-off stamps a new one, which
  /// makes it the name of the round the Set is on - what a "has this been
  /// listened to" mark is filed under, so a Set that comes back is unheard
  /// again without anybody clearing anything.
  final String workflowUpdatedAt;
  final String workflowStatus;
  final String roleKey;
  final String bookName;
  final String languageName;

  /// The Set's name in the source language - Urdu, in the data as it stands.
  ///
  /// Empty for a Set the server has no translation for, which is why nothing
  /// reading this may assume it is there.
  final String slName;

  /// The stage that sent this Set back, when one did.
  ///
  /// Written by whoever sends it back and cleared when it moves on again, so
  /// a value here means the Set is going round a second time - and whoever
  /// picks it up is owed the reason before they start.
  final String redoFromStage;

  /// Who sent the Set back, named the way the website names them - its
  /// `REDO_FROM_LABELS`. The back translator is a person where the other two
  /// are stages, because that is who the drafter will be answering to: the
  /// Set goes straight back to them, not round the pipeline again.
  String get redoFromLabel => switch (redoFromStage) {
    'peer' => 'Peer Check',
    'community_review' => 'Community Review',
    'back_translation' => 'Back Translator',
    'consultant' => 'Consultant',
    _ => WorkQueue.labelForStatus(redoFromStage),
  };

  /// What to put on screen, in whichever language the reader has chosen.
  ///
  /// Every screen that titles a Set reads this rather than [name], so the
  /// app-bar toggle moves all of them together. [name] itself is still the
  /// English one, and is what exported file names are built from - a
  /// filename in a script the phone's file manager may not render is a file
  /// nobody can find again.
  String get displayName => NameLanguage.pick(english: name, source: slName);

  String get subtitle =>
      [bookName, languageName].where((part) => part.isNotEmpty).join(' · ');

  /// Mirrors `queueInfo()`'s match block. The draft-progress variant (the
  /// "3 of 7 recorded" label) needs the Set's leaves, so it is applied by the
  /// screen once those are loaded rather than here.
  ({String label, Color color, IconData icon}) get queueInfo {
    final label = switch ((roleKey, workflowStatus)) {
      // Who from, as well as that it happened: three different people can
      // send a Set back, and which of them it was says what kind of change
      // is wanted before the Set has even been opened.
      ('drafter', 'redo') =>
        redoFromLabel.isEmpty
            ? 'Sent back - needs changes'
            : 'Sent back from @stage - needs changes'.trParams({
                'stage': redoFromLabel.tr,
              }),
      ('drafter', 'not_started') => 'Not started',
      ('drafter', 'recorded') => 'In progress',
      ('drafter', 'community_setup') => 'Add community questions',
      ('drafter', 'community_test') => 'Run community test',
      ('drafter', 'approved') => 'Approved',
      ('peer', 'peer') => 'Ready for your check',
      ('peer', 'community_review') => 'Ready for review',
      ('back_translator', 'back_translation') => 'Needs back translation',
      ('consultant', 'consultant') => 'Ready for consultant check',
      _ => workflowStatus.replaceAll('_', ' '),
    };

    // The stage's own colour and icon, so a Set in a list wears the same
    // badge as the tile it was opened from.
    final meta = WorkQueue.metaForStatus(workflowStatus);
    return (
      label: label,
      color: meta?.color ?? const Color(0xFF4B4870),
      icon: meta?.icon ?? Icons.circle_outlined,
    );
  }
}

/// A passage (or sub passage) inside a Set, with everything the work screens
/// need to show its state without another query.
class SetLeaf {
  const SetLeaf({
    required this.type,
    required this.id,
    required this.label,
    required this.verseRange,
    required this.sortOrder,
    required this.sourceScript,
    this.sourceScriptFromFile = false,
    this.targetScriptFromFile = false,
    required this.targetScript,
    required this.sourceAudioPath,
    required this.takesCount,
    required this.finalTake,
    required this.openMarks,
  });

  final String type;
  final String id;
  final String label;
  final String verseRange;
  final int sortOrder;
  final String sourceScript;

  /// Whether the script columns named a `.txt` file, as opposed to holding a
  /// line of text typed into the row. Only a file is the passage; anything
  /// else is a note about it, and is not shown as script.
  final bool sourceScriptFromFile;
  final bool targetScriptFromFile;

  /// The translation, once a drafter has written one.
  final String targetScript;
  final String sourceAudioPath;
  final int takesCount;
  final Map<String, dynamic>? finalTake;
  final int openMarks;

  /// What this leaf answers to wherever a single string has to name it - a
  /// segment of the merged recording, a pin on its waveform, a key in a map.
  ///
  /// A passage's key is its bare id and a sub-passage's carries its type,
  /// because the two are numbered in different tables and "12" can be one of
  /// each in the same Set. See [keyOf] and [parseKey].
  String get key => keyOf(type, id);

  static String keyOf(String type, String id) =>
      type == 'sub_passage' ? 'sub_passage:$id' : id;

  /// The type and id a [key] stands for.
  static ({String type, String id}) parseKey(String key) =>
      key.startsWith('sub_passage:')
      ? (type: 'sub_passage', id: key.substring('sub_passage:'.length))
      : (type: 'passage', id: key);

  bool get hasFinal => finalTake != null;
  bool get hasSourceAudio => sourceAudioPath.isNotEmpty;
  bool get hasSourceScript => sourceScriptFromFile && sourceScript.isNotEmpty;
  bool get hasTargetScript => targetScriptFromFile && targetScript.isNotEmpty;

  /// Recording is blocked without source material, matching the Laravel
  /// leaf screen's `$missingSource` guard.
  bool get missingSource => !hasSourceAudio || !hasSourceScript;

  String get finalAudioPath =>
      finalTake?['audio_path']?.toString().trim() ?? '';

  String get statusLabel {
    if (hasFinal) return 'Finalized';
    if (takesCount > 0) {
      return '$takesCount take${takesCount == 1 ? '' : 's'}';
    }
    return 'Not started';
  }
}
