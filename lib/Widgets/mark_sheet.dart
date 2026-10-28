import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:livuka/services/user_store.dart';
import 'package:livuka/Widgets/recording_timer.dart';
import 'package:livuka/Audio/audio_bus.dart';
import 'package:livuka/Audio/take_recorder.dart';
import 'package:livuka/Widgets/live_waveform.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/permissions.dart';
import 'package:livuka/services/qc_service.dart';
import 'package:livuka/services/services.dart';

/// What the composer produced: typed text, a recording, or both.
class MarkDraft {
  const MarkDraft({required this.text, required this.audioPath});

  final String text;
  final String? audioPath;
}

/// The app's port of the web `mark-popup` partial — one composer for every
/// place a question, answer or note is written.
///
/// Text and voice are both offered everywhere on purpose: the people using
/// these screens include community members who may not read or write the
/// language being translated, and a question they cannot ask is a question
/// that does not get asked.
class MarkSheet extends StatefulWidget {
  const MarkSheet({
    super.key,
    required this.title,
    this.subtitle = '',
    this.hint = 'Type it here',
    this.accent = const Color(0xFF1D6FD0),
    this.icon = Icons.question_mark_rounded,
  });

  final String title;
  final String subtitle;
  final String hint;
  final Color accent;

  /// What is being written here - a question, an answer, a comment. Drawn in
  /// black beside the title, because it names the task rather than colouring
  /// it, and the colour on that line was one more thing to read.
  final IconData icon;

  static Future<MarkDraft?> show(
    BuildContext context, {
    required String title,
    String subtitle = '',
    String hint = 'Type it here',
    Color accent = const Color(0xFF1D6FD0),
    IconData icon = Icons.question_mark_rounded,
  }) {
    return showModalBottomSheet<MarkDraft>(
      context: context,
      isScrollControlled: true,
      // Rounded at the top, and not dismissed by a tap outside: a question
      // half spoken should not vanish because a thumb landed on the
      // waveform behind it.
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => MarkSheet(
        title: title,
        subtitle: subtitle,
        hint: hint,
        icon: icon,
        accent: accent,
      ),
    );
  }

  @override
  State<MarkSheet> createState() => _MarkSheetState();
}

class _MarkSheetState extends State<MarkSheet> {
  /// Whether this is being spoken rather than typed.
  ///
  /// Voice first, because the people these sheets are for include community
  /// members who may not write the language being translated - and a
  /// question they cannot ask is a question that does not get asked.
  bool _voice = true;

  final TextEditingController _controller = TextEditingController();
  final TakeRecorder _recorder = TakeRecorder();

  bool _recording = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    AudioBus.instance.addListener(_stopIfPlaybackStarts);
  }

  @override
  void dispose() {
    AudioBus.instance.removeListener(_stopIfPlaybackStarts);
    AudioBus.instance.release(_recorder);
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// Ends the recording when something starts to play.
  void _stopIfPlaybackStarts() {
    if (!_recording || AudioBus.instance.holds(_recorder)) return;

    toaster(AudioBus.recordingStoppedMessage);
    unawaited(_toggleRecording());
  }

  Future<void> _toggleRecording() async {
    try {
      await _record();
    } catch (e) {
      debugPrint('MARK RECORD FAILED: $e');
      if (mounted) setState(() => _recording = false);
      toaster('Could not start recording: @error'.trParams({'error': '$e'}));
    }
  }

  Future<void> _record() async {
    if (_recording) {
      // Cleared first: the bus is watched, and must find nothing still
      // recording when it is let go of.
      _recording = false;
      final path = await _recorder.stop();
      AudioBus.instance.release(_recorder);
      if (!mounted) return;
      setState(() => _recordedPath = path);
      if (path != null && await RecordingCheck.isSilent(path)) {
        toaster(RecordingCheck.silentMessage);
      }
      return;
    }

    // A tap on the mic is a decision to speak, not to speak over
    // playback: whatever was sounding stops here.
    AudioBus.instance.claim(_recorder);

    if (!await checkMicrophonePermission()) {
      if (await isMicrophoneBlocked()) {
        await openMicrophoneSettings();
      } else {
        toaster('Microphone permission is needed to record.');
      }
      return;
    }

    final directory = await UserStore.work();
    final marksDir = Directory(p.join(directory.path, 'marks'));
    await marksDir.create(recursive: true);

    await _recorder.record(
      path: p.join(
        marksDir.path,
        'mark-${DateTime.now().millisecondsSinceEpoch}.wav',
      ),
    );

    if (mounted) setState(() => _recording = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    final canSave = _voice ? _recordedPath != null : hasText;

    // Scrolls: on a phone on its side, with the keyboard up, the sheet has
    // less height than its own contents.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: 16),
          _modePicker(),
          const SizedBox(height: 18),
          // One or the other, never both at once. Offering a text box and a
          // mic together asked the writer to decide what they were doing
          // while they were doing it; the choice above settles that first,
          // and this is only what they chose.
          if (_voice) _voicePanel() else _textPanel(),
          const SizedBox(height: 18),
          // `#markSaveBtn` pulses on the website once a recording exists.
          PulseHalo(
            active: _voice && _recordedPath != null && !_recording,
            borderRadius: BorderRadius.circular(10),
            child: _saveButton(context, canSave),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(BuildContext context, bool canSave) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: MainApp.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: (!canSave || _recording)
                  ? null
                  : () => Navigator.pop(
                      context,
                      MarkDraft(
                        text: _controller.text.trim(),
                        audioPath: _recordedPath,
                      ),
                    ),
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Save'.tr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Icon(widget.icon, size: 18, color: Colors.black),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (widget.subtitle.isNotEmpty)
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MainApp.mutedText,
                  ),
                ),
            ],
          ),
        ),
        // Closing is a decision too, and one people look for at the top
        // right. Without it the only way out of the sheet is a swipe, which
        // is not obvious to everyone using these screens.
        InkWell(
          onTap: _recording ? null : () => Navigator.pop(context),
          customBorder: const CircleBorder(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(Icons.close, size: 17, color: Color(0xFF4B5563)),
          ),
        ),
      ],
    );
  }

  /// Voice or text, and which of them this is going to be.
  Widget _modePicker() {
    return Row(
      children: [
        Expanded(
          child: _ModeTab(
            icon: Icons.mic,
            label: 'Voice',
            selected: _voice,
            // Not while a recording is running: switching away would leave
            // it going with nothing on screen to stop it.
            onTap: _recording ? null : () => setState(() => _voice = true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ModeTab(
            icon: Icons.keyboard,
            label: 'Text',
            selected: !_voice,
            onTap: _recording ? null : () => setState(() => _voice = false),
          ),
        ),
      ],
    );
  }

  Widget _textPanel() {
    return TextField(
      controller: _controller,
      maxLines: 4,
      minLines: 3,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: widget.hint.tr,
        // Grey at rest and grey with the cursor in it. Left alone, Material
        // rings a focused field in the colour scheme's primary - a purple
        // this app uses nowhere else, on the one control somebody is looking
        // straight at.
        border: _fieldBorder(const Color(0xFFE5E7EB)),
        enabledBorder: _fieldBorder(const Color(0xFFE5E7EB)),
        focusedBorder: _fieldBorder(const Color(0xFF9CA3AF)),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color colour) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: colour),
  );

  Widget _voicePanel() {
    if (_recording) {
      return Column(
        children: [
          LiveWaveform(recorder: _recorder, color: widget.accent, height: 56),
          const SizedBox(height: 12),
          const RecordingTimer(fontSize: 14),
          const SizedBox(height: 14),
          PulseHalo(
            active: true,
            color: const Color(0xFFDC2626),
            minSize: 72,
            maxSize: 120,
            child: _RecordButton(recording: true, onTap: _toggleRecording),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to stop'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
          ),
        ],
      );
    }

    if (_recordedPath != null) {
      return Column(
        children: [
          // The recording itself, not a word about it: nobody should have to
          // save a mark to find out what they just said.
          AudioClip(
            key: ValueKey(_recordedPath),
            filePath: _recordedPath!,
            showSpeed: false,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _recordedPath = null),
                icon: const Icon(Icons.delete_outline, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                ),
                label: Text('Discard'.tr, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: _toggleRecording,
                icon: const Icon(Icons.mic, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: MainApp.primaryGreen,
                ),
                label: Text(
                  'Record again'.tr,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        PulseHalo(
          active: true,
          color: const Color(0xFFDC2626),
          minSize: 72,
          maxSize: 120,
          child: _RecordButton(recording: false, onTap: _toggleRecording),
        ),
        const SizedBox(height: 10),
        Text(
          'Tap to record'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
        ),
      ],
    );
  }
}

/// One half of the Voice / Text switch.
class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MainApp.primaryGreen : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? MainApp.primaryGreen : const Color(0xFFE5E7EB),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
              const SizedBox(width: 8),
              Text(
                label.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round record button, and the stop button it becomes.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onTap});

  final bool recording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: const Color(0xFFDC2626),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 62,
          height: 62,
          child: Icon(
            recording ? Icons.stop_rounded : Icons.mic,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
    return Center(child: button);
  }
}
