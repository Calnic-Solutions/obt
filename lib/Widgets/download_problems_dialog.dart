import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Audio/media_prefetch.dart';
import 'package:livuka/main.dart';

/// Asks what to do about the files that did not download.
///
/// One card to a file, saying what it is, what it is for and where it
/// belongs, and why it did not come - with the choice beside it. A file is
/// tried again unless it is told to be skipped: trying again costs a wait,
/// and skipping costs the file.
class DownloadProblemsDialog extends StatefulWidget {
  const DownloadProblemsDialog({super.key, required this.failed});

  final List<MediaFile> failed;

  /// Shows the dialog and answers with the files to try again. The rest
  /// were skipped.
  static Future<List<MediaFile>> ask(List<MediaFile> failed) async {
    if (failed.isEmpty) return const [];

    final again = await Get.dialog<List<MediaFile>>(
      DownloadProblemsDialog(failed: failed),
      // A tap outside is not an answer to a question like this one.
      barrierDismissible: false,
    );
    return again ?? const [];
  }

  @override
  State<DownloadProblemsDialog> createState() => _DownloadProblemsState();
}

class _DownloadProblemsState extends State<DownloadProblemsDialog> {
  static const Color _bad = Color(0xFFDC2626);

  /// The files to go on without.
  final Set<MediaFile> _skipped = {};

  void _answer() => Get.back(
    result: [
      for (final file in widget.failed)
        if (!_skipped.contains(file)) file,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.failed.length;
    final retrying = count - _skipped.length;

    return PopScope(
      // The back button is not an answer either.
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 22, color: _bad),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (count == 1
                                ? '@count file did not download'
                                : '@count files did not download')
                            .trParams({'count': '$count'}),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MainApp.titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose for each file: try again, or skip it. A skipped '
                          'file is tried again at the next Check for updates.'
                      .tr,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: MainApp.mutedText,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: count,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final file = widget.failed[index];
                      return _FileCard(
                        file: file,
                        skipped: _skipped.contains(file),
                        onChanged: (skip) => setState(
                          () =>
                              skip ? _skipped.add(file) : _skipped.remove(file),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (count > 1)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(_skipped.clear),
                          child: Text('Try all again'.tr),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _skipped.addAll(widget.failed)),
                          style: TextButton.styleFrom(foregroundColor: _bad),
                          child: Text('Skip all'.tr),
                        ),
                      ),
                    ],
                  ),
                FilledButton(
                  onPressed: _answer,
                  style: FilledButton.styleFrom(
                    backgroundColor: MainApp.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    retrying == 0
                        ? 'Continue without these files'.tr
                        : (retrying == 1
                                  ? 'Try @count file again'
                                  : 'Try @count files again')
                              .trParams({'count': '$retrying'}),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.skipped,
    required this.onChanged,
  });

  final MediaFile file;
  final bool skipped;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                file.isScript
                    ? Icons.description_outlined
                    : Icons.graphic_eq_rounded,
                size: 16,
                color: MainApp.primaryGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  file.kind.label.tr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MainApp.titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (file.setName.isNotEmpty) _line('Set', file.setName),
          if (file.passageName.isNotEmpty) _line('Passage', file.passageName),
          _line('Used for', file.kind.use.tr),
          _line('File', file.fileName),
          _line(
            'Problem',
            file.failure ?? 'The file could not be downloaded.'.tr,
            color: const Color(0xFF991B1B),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Choice(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  chosen: !skipped,
                  color: MainApp.primaryGreen,
                  onTap: () => onChanged(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Choice(
                  label: 'Skip',
                  icon: Icons.skip_next_rounded,
                  chosen: skipped,
                  color: const Color(0xFFDC2626),
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String name, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${name.tr}: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: color ?? const Color(0xFF374151),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.chosen,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool chosen;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chosen ? color : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: chosen ? color : const Color(0xFFD1D5DB)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: chosen ? Colors.white : const Color(0xFF374151),
              ),
              const SizedBox(width: 6),
              Text(
                label.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: chosen ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
