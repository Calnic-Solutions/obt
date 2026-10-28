import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/sheet_host.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/take_repository.dart';

/// What a Community Review send-back is about: the question the community
/// was asked, the answer they gave, and the reviewer's Dislike of it - the
/// website's "Community Review feedback" popup.
///
/// The three are shown together because the reply on its own is
/// meaningless: "issues" tells the drafter nothing until they can see what
/// was asked and what was answered.
class QaFeedbackSheet extends StatelessWidget {
  const QaFeedbackSheet({super.key, required this.question});

  final CommunityQuestion question;

  static Future<void> show(BuildContext context, CommunityQuestion question) =>
      showAppSheet(QaFeedbackSheet(question: question), scrolls: true);

  /// Whether [question] is one the reviewer disliked and the drafter has
  /// still to act on.
  static bool isOpenDislike(CommunityQuestion question) =>
      question.isDisliked && (question.reaction?.isOpen ?? false);

  @override
  Widget build(BuildContext context) {
    final reply = question.reaction;

    // Three recordings can be taller than a phone: the sheet scrolls.
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 22,
                  color: Color(0xFF3FC3EE),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Community Review feedback'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MainApp.titleColor,
                    ),
                  ),
                ),
                if (question.leafLabel.isNotEmpty)
                  Text(
                    question.leafLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MainApp.mutedText,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              label: 'Question',
              text: question.text,
              audioPath: question.audioPath,
              audioKey: 'q-${question.id}',
              emptyText: 'Voice question',
            ),
            const SizedBox(height: 10),
            _Section(
              label: 'Answer',
              text: question.answer?.text ?? '',
              audioPath: question.answer?.audioPath ?? '',
              audioKey: 'a-${question.answer?.id}',
              emptyText: (question.answer?.audioPath ?? '').isNotEmpty
                  ? 'Voice answer'
                  : 'No answer was given.',
            ),
            if (reply != null) ...[
              const SizedBox(height: 10),
              _Section(
                label: reply.authorName.isEmpty
                    ? 'Reply'.tr
                    : '${'Reply'.tr} - ${reply.authorName}',
                text: reply.text,
                audioPath: reply.audioPath,
                audioKey: 'r-${reply.id}',
                emptyText: 'Voice reply',
                // Red: this is the part that sent the Set back.
                tint: const Color(0xFFDC2626),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.text,
    required this.audioPath,
    required this.audioKey,
    required this.emptyText,
    this.tint,
  });

  final String label;
  final String text;
  final String audioPath;
  final String audioKey;
  final String emptyText;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final hasAudio = audioPath.isNotEmpty;
    final colour = tint;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour == null
            ? const Color(0xFFF7F8FA)
            : colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: colour == null
            ? null
            : Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.tr.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: colour ?? MainApp.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text.isNotEmpty
                ? text
                : hasAudio
                ? emptyText.tr
                : emptyText.tr,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: text.isNotEmpty ? MainApp.titleColor : MainApp.mutedText,
            ),
          ),
          if (hasAudio) ...[
            const SizedBox(height: 6),
            AudioClip(
              key: ValueKey(audioKey),
              filePath: audioPath,
              showSpeed: false,
              showExpand: false,
              accent: colour ?? MainApp.primaryGreen,
            ),
          ],
        ],
      ),
    );
  }
}
