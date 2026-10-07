import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/l10n/strings.dart';
import '../core/services/app_update_fetcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme_colors.dart';

class _Release {
  final String version;
  final int buildNumber;

  /// Android versionCode for this release. Same role as the equivalent
  /// field in the update-checker's _ReleaseNote - a v1.0.12 device has
  /// Android versionCode=13 while the manifest's `build` is 27, and using
  /// the manifest `build` here would mark every old release as "newer than
  /// you" and the changelog sheet as a wall of red "Baru" badges.
  final int androidVersionCode;
  final String? date;
  final String headline;
  final List<String> newBullets;
  final List<String> fixBullets;
  final String type;

  const _Release({
    required this.version,
    required this.buildNumber,
    required this.androidVersionCode,
    this.date,
    required this.headline,
    this.newBullets = const [],
    this.fixBullets = const [],
    this.type = 'patch',
  });

  factory _Release.fromJson(Map<String, dynamic> j) {
    // New manifests (added by this release) send a `headline` plus a
    // `sections` array. Old manifests still in the history (1.0.10 / 1.0.9
    // etc.) send a single `notes` string. Parse both shapes here.
    final headline = (j['headline'] as String?)?.trim() ??
        (j['notes'] as String?)?.trim() ??
        '';
    final sections = (j['sections'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final newBullets = <String>[];
    final fixBullets = <String>[];
    for (final s in sections) {
      final items = (s['items'] as List? ?? const []).whereType<String>();
      switch ((s['kind'] as String?) ?? 'notes') {
        case 'new':
        case 'feature':
          newBullets.addAll(items);
          break;
        case 'fix':
        case 'fixed':
        case 'bugfix':
          fixBullets.addAll(items);
          break;
        default:
          newBullets.addAll(items);
      }
    }
    // Empty array: fall back to the legacy single-string `notes` so older
    // manifests still render reasonably until they roll out of the
    // history window.
    if (newBullets.isEmpty && fixBullets.isEmpty && headline.isNotEmpty) {
      final lines = headline.split('\n').toList();
      while (lines.isNotEmpty && !lines.first.trimLeft().startsWith('•')) {
        lines.removeAt(0);
      }
      newBullets.addAll(lines
          .map((l) => l.replaceFirst('•', '').trim())
          .where((l) => l.isNotEmpty));
    }
    final buildNumber = (j['build'] as num?)?.toInt() ?? 0;
    // Same Android-versionCode fallback as the update checker: the
    // manifest's monotonic `build` is not the number the device reports,
    // so we use `androidVersionCode` (falling back to `build`) to decide
  // what is actually newer than the installed app.
    final androidVersionCode =
        (j['androidVersionCode'] as num?)?.toInt() ?? buildNumber;
    return _Release(
      version: j['version'] as String? ?? '',
      buildNumber: buildNumber,
      androidVersionCode: androidVersionCode,
      date: j['date'] as String?,
      headline: headline.split('\n').first.trim(),
      newBullets: newBullets,
      fixBullets: fixBullets,
      type: j['type'] as String? ?? 'patch',
    );
  }
}

/// Release history, straight from `/api/app/version`. Every published build
/// is listed newest-first and marked relative to what is installed, so a user
/// on an old build can see what they missed.
Future<void> showVersionSheet(BuildContext context, PackageInfo pkg) async {
  final s = stringsFor(Localizations.localeOf(context));
  final installedBuild = int.tryParse(pkg.buildNumber) ?? 0;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, controller) => Container(
        decoration: BoxDecoration(
          color: ctx.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ctx.colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.changelogTitle,
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pkg.version} (${pkg.buildNumber})',
                          style: TextStyle(
                            color: ctx.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: ctx.colors.textSecondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<_Release>>(
                future: _fetchHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final releases = snapshot.data ?? const <_Release>[];
                  if (releases.isEmpty) {
                    return Center(
                      child: Text(
                        s.noReleaseNotes,
                        style: TextStyle(color: ctx.colors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: releases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = releases[index];
                      return _ReleaseCard(
                        release: r,
                        isCurrent: r.androidVersionCode == installedBuild,
                        isNew: r.androidVersionCode > installedBuild,
                        currentLabel: s.youAreHere,
                        newLabel: s.newBadge,
                        s: s,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<List<_Release>> _fetchHistory() async {
  try {
    final data = await AppUpdateFetcher.fetchVersion(0);
    final raw = data['history'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(_Release.fromJson).toList();
  } catch (_) {
    return const [];
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.release,
    required this.isCurrent,
    required this.isNew,
    required this.currentLabel,
    required this.newLabel,
    required this.s,
  });

  final _Release release;
  final bool isCurrent;
  final bool isNew;
  final String currentLabel;
  final String newLabel;
  final Str s;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.08)
            : palette.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppColors.primary : palette.border,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${s.versionNumberLabel} ${release.version}',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              if (isNew)
                _Chip(label: newLabel, color: AppColors.primary)
              else if (isCurrent)
                _Chip(label: currentLabel, color: AppColors.info),
              const Spacer(),
              if (release.date != null)
                Text(
                  release.date!,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
            ],
          ),
          if (release.headline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              release.headline,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          if (release.newBullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            _BulletSection(
              title: s.releaseNotesSectionNew,
              items: release.newBullets,
              color: AppColors.primary,
              palette: palette,
            ),
          ],
          if (release.fixBullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            _BulletSection(
              title: s.releaseNotesSectionFix,
              items: release.fixBullets,
              color: AppColors.success,
              palette: palette,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Yang baru" / "Fixes" block. Headings use the section colour so the eye
/// can tell at a glance which kind of change a release brings.
class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.items,
    required this.color,
    required this.palette,
  });

  final String title;
  final List<String> items;
  final Color color;
  final dynamic palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
