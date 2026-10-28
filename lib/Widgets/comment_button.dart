import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The invitation to say something about the recording.
///
/// A white panel of its own under the player: the same surface as the cards
/// around it, so it reads as the next thing to do rather than as a control
/// competing with the recording above it.
class CommentButton extends StatelessWidget {
  const CommentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.wechat_rounded,
  });

  final String label;
  final IconData icon;

  /// Null while something else is in flight, which greys it out.
  final VoidCallback? onPressed;

  static const Color _ink = Color(0xFF040134);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: _ink,
          disabledForegroundColor: const Color(0xFF9CA3AF),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label.tr,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
