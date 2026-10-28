# Where the brief, the manual and the code disagree

The brief says: *where the manual and the code disagree, the code wins; report the
discrepancy.* "The code" here is the Laravel app at `C:\Users\lenov\Desktop\Flutter_Apps\OBT_Project\OBT_WEB`.
Everything below was checked against it, and on 2026-09-23 against the live
database dump `twftwpga_obt.sql` (see section E).

## A. Rules where the code is stricter than the brief — the app follows the code

| # | Brief | Laravel code | App does |
|---|---|---|---|
| A1 | Community Review: an unanswered question blocks both buttons; a Dislike enables Send back. Nothing is said about what Forward needs. | `CommunityReviewController::forward` refuses unless **every** current answer is Liked (`allLiked`). `sendBack` needs `anyDisliked`. | Forward needs every answer Liked; Send back needs at least one Dislike; an unanswered question blocks both. |
| A2 | Back Translator: only the listen gate and a back translation are mentioned for Submit. | `BackTranslatorController::submit` also refuses while the back translator has **open comments of their own** on the recording ("send back to the Drafter instead, or remove them first"). | Same, with that reason shown under the button. |
| A3 | Peer Check: only Send back is described as needing an open comment. | `PeerController::forward` refuses while any open peer comment stands ("Resolve or remove open comments before sending forward"). | Same. |
| A4 | "A comment on a take the Drafter has since replaced stops counting." | `SetLeaves::isCurrentForLeaf`: by `take_id` when the comment has one, otherwise by comparing `created_at` with the final take's `recorded_at`. | Identical, date fallback included (`TakeRepository.isCurrentFor`). It matters most for community questions, which the website creates with no `take_id` at all. |
| A5 | A reaction is "a Like or Dislike on an answer". | Stored as a `take_comments` row: `type=reply`, `parent_id` = the **answer's** id, `reaction` = like/dislike, `status` = `resolved` for a Like and `open` for a Dislike; one per answer, newest replaces. | Identical. (The previous build of this app hung replies off the *question*; those are still read.) |

## B. Things the brief asks for that the sync API cannot do yet

> **Update 2026-09-23 (afternoon):** the OBT_WEB controllers were changed the
> same day. B1, B5, B7 and B8 are now done server-side, and B2/B3 are mostly
> done (see each item). The app's client-side versions of the same rules are
> kept: they are what a phone shows before its next sync, and they are
> idempotent against the server's. Whether the DEPLOYED server carries these
> edits is a separate question - check before relying on them.

The app talks to `POST /api/data-sync` (bulk, all-or-nothing per request) and
`GET /api/data-collection`. The per-action REST endpoints under `/api/workbench/*`
validate properly but need a live connection for every tap, so they cannot serve an
offline-first app. These are **server changes I did not make** (the Laravel app is
outside this project) — each is small:

1. **DONE 2026-09-23.** `applyTakeComments` now stores `reaction` on create and
   on update (update only when the row names the key). *Was:* **`reaction` is dropped.** `DataSyncController::applyTakeComments` does not pass
   `reaction` to `TakeComment::create`, and the update branch only writes
   `status`/`text`. A Like/Dislike made on the phone reaches the server as a plain
   reply. *Until fixed the app infers the verdict from `status` (open = Dislike,
   resolved = Like), which is how the web stores them, so nothing is lost on the
   phone — but the website will not show the thumb.*
   Fix: add `'reaction' => $row['reaction'] ?? null` to the create array and to the
   update array.
   **DONE 2026-09-29.** `applyTakeComments` now stores `reaction` on a new row and
   updates it on an existing one when the row names it.
2. **PARTLY DONE 2026-09-23.** `applySetMoves` now runs the web's send-back
   cleanup (`clearForSet` / `clearForOpenComments`, `SendBackLog::record`) on
   a move to `redo`, and `clearBackTranslationRound` on a move to `peer` /
   `back_translation`. It still does not check the gate rules themselves.
   *Was:* **The server does not validate a queued hand-off.** The brief says "the server
   still validates every queued action (QC passed, no open comments, recordings
   heard)". `applySetMoves` writes whatever `workflow_status` it is given; it checks
   only that the Set is still assigned to the user. All gate/QC/comment rules are
   therefore enforced on the phone only. The app *does* surface every rejection the
   server can produce (reassigned Set, non-WAV file, missing recording, bad status)
   on the Sync status screen, keeps the work, and stops that Set's queue.
3. **MOSTLY DONE 2026-09-23.** A send-back now clears Finals on the server (see
   B2). Two holes remain: (a) in `take` mode the Community Review send-back
   calls only `clearForOpenComments`; the web also calls
   `clearForOpenQuestionReplies`, so a Dislike on a passage question does not
   un-finalize that passage on the server (one extra line in `applySetMoves`);
   (b) "Remove Final" on a take, outside a send-back, still cannot be sent.
   The take update branch now accepts `blocked_reason`.
   *Was:* **Send-back side effects are not applied by data-sync.** On the web,
   `sendBack` clears `final_takes` (`clearForOpenComments` / `clearForSet`).
   `data-sync` has no way to delete a `final_takes` row, so:
   - clearing Finals on a send-back,
   - "Remove Final" on a take,
   are applied on the phone and **not** on the server; the next data load hands the
   old Final back. The app defends against this: while the Drafter holds a Set, a
   Final take that carries an open comment/Dislike is treated as not Final.
   Fix: accept `final_takes` rows with a `deleted` marker, or apply the web's
   clearing inside `applySetMoves` when `workflow_status` becomes `redo`.
4. **Comments cannot be deleted through data-sync.** The web has
   `DELETE take-comments/{id}` (author only). For a comment the server already
   holds, the app marks it `resolved` and hides it — it stops counting everywhere,
   but the row survives server-side.
5. **DONE 2026-09-23.** `data-collection` now returns a `settings` object
   (every `settings` row, key to value); the app already read it from there.
   *Was:* **`send_back_based_on` is not in the data-collection payload.** The app reads it
   from a `settings` block or from the Set row if the server ever sends one, and
   otherwise behaves as `'take'` (the server default). Until it is sent, a project
   set to `'set'` will clear only the faulted passages on the phone.
6. **No resumable/chunked upload.** `data-sync` takes the whole batch as one
   multipart request. The app keeps batches small by sending **one Set per
   request**, never unmarks work until the server says yes, and retries the whole
   Set on failure — a half-uploaded file is simply re-sent. True resumable upload
   needs a server endpoint (e.g. tus or S3 multipart presigning).
7. **DONE 2026-09-23** - see B2. *Was:* **The old back-translation round is not cleared by data-sync.** On the web,
   the drafter's `sendToPeer` deletes the Set's back translations, consultant
   comments and back-translator replies (`clearBackTranslationRound`).
   `applySetMoves` does none of that. The phone hides them locally and keeps
   them hidden across data loads, and resolves the comments through the sync,
   but the old `back_translations` row survives on the server and the website
   will still show it. Fix: call `clearBackTranslationRound` from
   `applySetMoves` when a drafter's Set moves to `peer` or `back_translation`.
8. **DONE 2026-09-23** (`parseRecordedAt`, falls back to `now()`). *Was:* `recorded_at` sent by the phone is ignored (`now()` is used), so a take recorded
   offline on Monday and synced on Friday is dated Friday on the server.
9. **DONE 2026-09-29 (server).** A Consultant's send-back through data-sync
   deleted the Consultant's own comments and the back translation, because
   `applySetMoves` cleared the back-translation round on every move into
   `back_translation`. It now clears only when the Set is leaving one of the
   Drafter's stages (`$fromDrafter`). Checked against the live server the same
   day; the app's re-send workaround (`_restoreRounds`) was removed.

## B2. Places the app is deliberately STRICTER than the web (checked 2026-09-22)

- **Consultant Approve** is blocked by an open consultant comment in the app. The
  web's `ConsultantController::approve` has no such check (its `hasOpenComment`
  helper exists but is unused there). The brief asked for the block; kept.
- **Community Review send-back** is blocked while any question is unanswered in the
  app. On the web an unanswered question only stops Forward. The brief asked for
  both; kept.
- **Back Translator Submit** has a listen gate in the app (brief); the web has none.
- **Automated QC finds the voice first** (since 2026-09-29, at the user's
  request). The website's `TakeQc` measures loudness and calls speech
  whatever is 8 dB over the take's own noise floor; a 36 s take made on a
  Moto G9 with nobody speaking passed as 26% speech on both. The app now
  runs `VoiceDetector` (pitch, 70-400 Hz, and at least -40 dBFS) and judges
  four checks against the voice it finds:
  - *Voice detected*: share of the take that is a voice (limit 10%, as before).
    With none, the report and the QC popup say to speak and record again.
  - *Head / tail silence*: time before the first word and after the last
    (limit 1.5 s, as before), not time below -45 dBFS.
  - *Volume consistency*: spread of the voice's own level (limit 18 dB, as before).
  - *Background noise* (`enhanced_qc`): sound that is not the voice and is
    within 10 dB of it, or anything 15 dB over it; 0.5 s allowed, as before.
  Clipping, noise floor, duration, sample rate and truncation are still the
  website's, figure for figure (154 recordings compared on 2026-09-29).
  The same take can therefore grade differently on the website. Known
  limit: a steady tone in the voice's range counts as voice.

## B3. Web behaviour the app has no equivalent for (as of 2026-09-22)

- Time tracking (`TimeTrackController`, per-page heartbeats) - no sync path.
- `SendBackLog` on every send-back - no column in the sync payload.
- Drafter self-notes on the merged draft (`stage_key='drafter'` comments) - the app
  does not offer them.
- The `/api/workbench/*` REST tree - the validated per-action endpoints. Unused: they
  need a live connection per tap. If the server ever adds them to `data-sync`'s
  side effects, several client-side workarounds above can go.

## E. Live database vs the app's SQLite (checked 2026-09-23 against `twftwpga_obt.sql`)

The app uses exactly three endpoints: `POST /api/auth/login`,
`GET /api/data-collection` and `POST /api/data-sync`. SQLite holds every server
row as a JSON payload (one `payload` column per table), so "schema" on the phone
means the field names the Dart code reads and writes. Every table in the dump
that reaches the app was compared column by column.

**Matches.** `obt_sets` (incl. `sl_name`, `redo_from_stage`, the ten
`workflow_status` values), `obt_passages`, `obt_sub_passages`, `takes` (incl.
`qc_results`, `blocked_reason`, the four `status` values), `final_takes`,
`take_comments` (incl. `reaction`, `position_seconds` at 3 decimals, the five
`type` values), `back_translations`, `set_assignments` (four `role_key` values),
`workflow_steps`, `books`, `book_links`, `users`. Everything `data-sync`
validates (`leaf_type`, take `status`, comment `type`/`status`, `local-` ids,
WAV-only files named by `audio_path` basename) is what the app sends.

**Fixed in the app on 2026-09-23.**

1. **Author names.** Server `take_comments` rows carry `author_id` only; the
   app read `author_name`, which exists only on rows written on the phone, so
   every comment, reply and Like/Dislike that came from the server showed with
   no author. Names are now resolved through the `users` table the same data
   load brings down (`TakeRepository.userNames`). Rows written on the phone
   now also carry `author_id`, so "mine" still holds after a sync has cleared
   the local flag. The server ignores the field and stamps the token's user.
2. **Boolean casts.** Eloquent sends `is_current`, `is_active` and
   `is_super_admin` as JSON `true`/`false`, not `1`/`0`. The app compared
   against `'0'`, so a `false` read as on. Both shapes are now read.

**Server side, after the OBT_WEB edits of 2026-09-23.**

- The dump has three migrations the local Laravel source does not:
  `2026_09_22_000001` (page_time_logs set/leaf), `2026_09_22_000002`
  (`send_back_logs`), `2026_09_22_000003` (`not_started` status). The models
  and controllers in `OBT_WEB` already use both, so the source is only missing
  the migration files. The local `DataSyncController` / `DataCollectionController`
  are now newer than whatever is deployed; deploy them together.
- `settings.send_back_based_on` is **`set`** in the live database. The app now
  receives it through the new `settings` block (B5) and honours it.
- Remaining server gaps: comment delete (B4), "Remove Final" outside a
  send-back (B3b), `clearForOpenQuestionReplies` on a Community Review
  send-back in `take` mode (B3a), no resumable upload (B6).
- `enhanced_qc` (`yes`/`no`) also arrives in `settings`; the website's
  `TakeQc` gates two extra checks on it. The app's QC does not read it yet.

## C. Brief vs reality

- **Hindi is not right-to-left.** Urdu is; Hindi (Devanagari) is a complex script
  written left to right.
- **The layout is not mirrored for Urdu** (decided 2026-09-21). The brief asked for
  RTL layout; in use, mirroring moved every control and threw Latin-script names to
  the far side, so the screen arrangement is held left-to-right in all three
  languages and only the text changes. Urdu text itself still reads right to left.
- **Mark colours.** Brief and website agree (voice question = mustard `#CA8A04`,
  text question = orange `#B45309`); the existing app had the two swapped. Fixed.
- **"QC runs on demand."** The app also runs QC once automatically when a take is
  saved, because the same pass is the format check that stops a non-WAV recording
  being queued (the server rejects those for the whole Set). The on-demand button
  is there as well. Left as it was; say if you want the automatic pass removed.
- **Take durations.** `audio_waveforms` 2.0.2 reports twice the real length on
  Android. The 5-second minimum and `duration_ms` were using that figure, so
  2.5-second takes were accepted and every stored duration was doubled. Fixed by
  timing the recording in the app (pauses excluded).

## D. Two faces: phone and desktop (added 2026-09-23)

The app has one set of controllers, rules and stores and two sets of screens.
A phone gets `lib/pages` (touch-first, as refined through 2026-09-22). Windows,
macOS and Linux get `lib/desktop`, which reproduces the website's workbench
layout from `OBT_WEB/resources/views/layouts/app.blade.php` and the
`workbench/*` views: the 64px topbar, `.ob-card` / `.ob-pill` / `.ob-btn`
tokens, the `.ob-player` card player, the fixed action bar, the pulsing
"do this next" ring and the pinned split layouts. The split is one switch
(`DesktopUi.enabled`) at the top of each page's `build`.

Where the desktop face knowingly differs from the website:

- **Send / check for updates** sits at the right of the dashboard's Workbench
  heading, with the unsent-changes pill. The website is online and has no
  such button; this app must have one. It is a click, not the phone's drag.
- **The 3-dot menu** offers Settings, Sync status and Logout. The website's
  "Change Password" has no equivalent in the app (B3).
- **Stage tiles** are the website's own, one per status, including its two
  Draft tiles "New Draft" (`not_started`) and "In Progress" (`recorded`)
  (since 2026-09-23; before that the desktop merged them). The phone keeps
  one Draft tile and its own labels.
- **Stage list screens show one Set**, the website's `nextPending`: the
  next Set to work on as a single card, with the website's cross-stage
  "Jump to a pending work item" select above it on New Draft / In Progress
  (since 2026-09-23; before that the desktop paged through every Set).
  New Draft offers an In Progress Set first, as the website does.
- **Audio playback on Windows runs on media_kit (libmpv)**, not
  audioplayers (since 2026-09-23). The Windows build of audioplayers posts
  its events from a non-platform thread, which Flutter warns about and
  which can drop a completion event. `lib/Audio/audio_backend.dart` picks
  the plugin per platform; phones keep audioplayers. Only
  `media_kit_libs_windows_audio` is depended on, so the phone bundles gain
  nothing.
- **The User Manual icon** in the topbar opens the website's public
  `/user-manual` in the browser, with the same role flags the website
  passes (since 2026-09-23).
- **The Drafter's set page** does not show the website's "Community Review
  feedback" card; that feedback lives under the Feedback tile, as on the phone.
- **Waveform bars are real** (from the file), where the website draws a
  synthetic pattern.
- **Approved Sets** carry a Download / Listen button and a download status
  line, because a desktop is offline-first too. The download only fetches
  the audio for listening in the app: since 2026-09-25 the website shows
  a "Task Done" indicator on a finished Set where its "Download this set"
  button was, so the app no longer writes a copy into the Downloads folder
  and both the desktop and the phone show the same indicator.
- **Comment, question and answer audio** plays through the same small card
  player as everything else rather than the browser's native `<audio>`.
- **Community Test** has no "Delete answer" (the phone has none either).
- **Messages are dialogs, not toasts** on the desktop, as on the website
  ("there are no toasts"): a centred card with one OK button. The phone
  keeps its toasts.
- **Responsive**: the website's single 900px breakpoint is honoured. Below
  it the content inset drops to 14px, card padding to 16px, the side
  chevrons to 46px, script splits and the record card stack, grids fall
  back to `auto-fit` column counts, and the login brand pane hides below
  760px. Nothing else changes with window size.
- **Settings and Change password** pages of the website are not ported; the
  desktop's 3-dot menu opens the app's own Settings panel.
