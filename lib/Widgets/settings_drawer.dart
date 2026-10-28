import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/l10n/app_locale.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/pages/manual_page.dart';
import 'package:livuka/pages/sync_status_page.dart';
import 'package:livuka/services/storage_usage.dart';
import 'package:livuka/services/sync_service.dart';
import 'package:livuka/services/work_queue.dart';

/// Who is signed in, and the two things they can do about it.
///
/// The workbench used to carry three icons - the tables, a settings cog that
/// did nothing, and sign out - in a row small enough that the wrong one was
/// easy to hit, with the most destructive of the three at the end. They live
/// here now, behind one cog, with sign out last and clearly apart.
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({
    super.key,
    required this.onSignOut,
    this.manualSection,
  });

  final VoidCallback onSignOut;

  /// The handbook chapter for the screen this panel was opened over, so
  /// "User manual" lands on the step the person is at rather than page one.
  final String? manualSection;

  @override
  Widget build(BuildContext context) {
    final user = SessionService.user ?? const {};

    final name = _first(user, ['name', 'Name', 'full_name', 'UserName']);
    final email = _first(user, ['email', 'Email', 'EmailID']);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(name: name, email: email),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  const _SectionLabel('Languages'),
                  FutureBuilder<List<String>>(
                    future: WorkQueue.assignedLanguages(),
                    builder: (context, snapshot) => _Chips(
                      values: snapshot.data ?? const [],
                      empty: snapshot.connectionState == ConnectionState.done
                          ? 'No Sets assigned yet.'
                          : 'Reading...',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _SectionLabel('Roles'),
                  _RoleChips(roles: MainApp.roles),
                  const _GroupHeading('App preferences'),
                  const _SectionLabel('App language'),
                  const _LanguagePicker(),
                  const _GroupHeading('Data & storage'),
                  const _StorageTile(),
                  const _SyncTile(),
                  const _GroupHeading('Help'),
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF4B5563),
                    ),
                    title: Text(
                      'User manual'.tr,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      'How to do each stage on this phone'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MainApp.mutedText,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: MainApp.mutedText,
                    ),
                    onTap: () {
                      Get.back();
                      Get.to(() => ManualPage(section: manualSection));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Last, and on its own. Signing out empties the device, so it
            // should never sit shoulder to shoulder with something ordinary.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MainApp.sendBackRed,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Get.back();
                    onSignOut();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(
                    'Sign out'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The first of [keys] the row actually carries, since the server has
  /// spelled these differently at different times.
  static String _first(Map<String, dynamic> user, List<String> keys) {
    for (final key in keys) {
      final value = user[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final shown = name.isEmpty ? 'Signed in'.tr : name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: MainApp.primaryGreen.withValues(alpha: 0.12),
            child: Text(
              shown.characters.first.toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MainApp.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MainApp.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        text.tr.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          // Spacing pulls the joined letters of Urdu apart.
          letterSpacing: AppLocale.isRtl ? 0 : 0.6,
          color: MainApp.mutedText,
        ),
      ),
    );
  }
}

/// One badge per role, in the website's colour and icon for it, so what a
/// person is here reads the same as it does on the Set list there.
class _RoleChips extends StatelessWidget {
  const _RoleChips({required this.roles});

  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No role assigned yet.'.tr,
          style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final role in roles)
            Builder(
              builder: (context) {
                final badge = WorkQueue.badgeForRole(role);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badge.bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badge.icon, size: 13, color: badge.fg),
                      const SizedBox(width: 5),
                      Text(
                        WorkQueue.labelForRole(role).tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: badge.fg,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.values, required this.empty});

  static const Color _slate = Color(0xFF475569);

  final List<String> values;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          empty.tr,
          style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              // Slate, so a language is not mistaken for a role: the four
              // role chips above each wear a stage's colour, and the brand
              // teal among them read as a fifth role.
              decoration: BoxDecoration(
                color: _slate.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _slate,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// English, Urdu or Hindi, each named in its own script.
///
/// Three large targets rather than a dropdown: the choice is made once, often
/// by somebody being shown the app for the first time, and a menu that has
/// to be opened to see what is in it is one more thing to explain.
class _LanguagePicker extends StatefulWidget {
  const _LanguagePicker();

  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  @override
  Widget build(BuildContext context) {
    // Each language named in itself, so it can be found by somebody who
    // cannot read the one currently showing.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<Locale>(
        initialValue: AppLocale.current,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          prefixIcon: const Icon(Icons.language_rounded, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        items: [
          for (final locale in AppLocale.supported)
            DropdownMenuItem(
              value: locale,
              child: Text(
                AppLocale.names[locale.languageCode]!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        onChanged: (locale) async {
          if (locale == null) return;
          await AppLocale.set(locale);
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

/// A heading over a group of settings - larger than the section labels
/// under it, so the panel reads as a few groups rather than a long list.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        text.tr,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: MainApp.titleColor,
        ),
      ),
    );
  }
}

/// How much of the phone the app is using, and a breakdown on tap.
class _StorageTile extends StatefulWidget {
  const _StorageTile();

  @override
  State<_StorageTile> createState() => _StorageTileState();
}

class _StorageTileState extends State<_StorageTile> {
  late Future<StorageUsage> _usage = StorageUsage.measure();
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StorageUsage>(
      future: _usage,
      builder: (context, snapshot) {
        final usage = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(
                Icons.sd_storage_outlined,
                color: Color(0xFF4B5563),
              ),
              title: Text(
                'Storage used'.tr,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                usage == null
                    ? 'Measuring...'.tr
                    : '@size on this phone'.trParams({
                        'size': StorageUsage.format(usage.total),
                      }),
                style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
              ),
              trailing: Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                color: MainApp.mutedText,
              ),
              onTap: () => setState(() {
                _open = !_open;
                // Re-measured each time it is opened: a take recorded
                // since is worth seeing counted.
                if (_open) _usage = StorageUsage.measure();
              }),
            ),
            if (_open && usage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
                child: Column(
                  children: [
                    _StorageRow(
                      label: 'Downloaded recordings',
                      bytes: usage.recordings,
                      total: usage.total,
                      color: const Color(0xFF4F46E5),
                    ),
                    _StorageRow(
                      label: 'Your recordings',
                      bytes: usage.takes,
                      total: usage.total,
                      color: MainApp.primaryGreen,
                    ),
                    _StorageRow(
                      label: 'Scripts',
                      bytes: usage.scripts,
                      total: usage.total,
                      color: const Color(0xFFCA8A04),
                    ),
                    _StorageRow(
                      label: 'Database',
                      bytes: usage.database,
                      total: usage.total,
                      color: const Color(0xFF475569),
                    ),
                    if (usage.other > 0)
                      _StorageRow(
                        label: 'Other',
                        bytes: usage.other,
                        total: usage.total,
                        color: const Color(0xFF98A2B3),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({
    required this.label,
    required this.bytes,
    required this.total,
    required this.color,
  });

  final String label;
  final int bytes;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : bytes / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label.tr, style: const TextStyle(fontSize: 12)),
              ),
              Text(
                StorageUsage.format(bytes),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MainApp.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 5,
              backgroundColor: const Color(0xFFEEF0F3),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// What is waiting to go up, and whether anything was refused - the same
/// figures the workbench's cloud icon used to carry, now here with the rest
/// of the phone's own housekeeping.
class _SyncTile extends StatefulWidget {
  const _SyncTile();

  @override
  State<_SyncTile> createState() => _SyncTileState();
}

class _SyncTileState extends State<_SyncTile> {
  late final Future<({int unsent, int problems})> _state = _read();

  static Future<({int unsent, int problems})> _read() async => (
    unsent: await SyncService.pendingCount(),
    problems: (await SyncService.problems()).length,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({int unsent, int problems})>(
      future: _state,
      builder: (context, snapshot) {
        final unsent = snapshot.data?.unsent ?? 0;
        final problems = snapshot.data?.problems ?? 0;

        final colour = problems > 0
            ? const Color(0xFFDC2626)
            : unsent > 0
            ? const Color(0xFFB45309)
            : const Color(0xFF4B5563);

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            problems > 0 ? Icons.cloud_off_outlined : Icons.cloud_sync_outlined,
            color: colour,
          ),
          title: Text('Sync status'.tr, style: const TextStyle(fontSize: 14)),
          subtitle: Text(
            snapshot.data == null
                ? 'Reading...'.tr
                : problems > 0
                ? (problems == 1
                          ? '@count Set was not sent'
                          : '@count Sets were not sent')
                      .trParams({'count': '$problems'})
                : unsent > 0
                ? (unsent == 1
                          ? '@count change waiting to send'
                          : '@count changes waiting to send')
                      .trParams({'count': '$unsent'})
                : 'Everything has been sent.'.tr,
            style: TextStyle(
              fontSize: 11,
              color: problems > 0 || unsent > 0 ? colour : MainApp.mutedText,
              fontWeight: problems > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: MainApp.mutedText),
          onTap: () {
            Get.back();
            Get.to(() => const SyncStatusPage());
          },
        );
      },
    );
  }
}
