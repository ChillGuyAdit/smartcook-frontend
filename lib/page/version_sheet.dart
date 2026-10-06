import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/l10n/strings.dart';
import '../core/services/app_update_fetcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme_colors.dart';

class _Release {
  final String version;
  final int build;
  final String? date;
  final String notes;

  const _Release({
    required this.version,
    required this.build,
    this.date,
    required this.notes,
  });

  factory _Release.fromJson(Map<String, dynamic> j) => _Release(
        version: (j['version'] ?? '').toString(),
        build: (j['build'] as num?)?.toInt() ?? 0,
        date: j['date'] as String?,
        notes: (j['notes'] ?? '').toString(),
      );
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
                        isCurrent: r.build == installedBuild,
                        isNew: r.build > installedBuild,
                        currentLabel: s.youAreHere,
                        newLabel: s.newBadge,
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
  });

  final _Release release;
  final bool isCurrent;
  final bool isNew;
  final String currentLabel;
  final String newLabel;

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
                'Versi ${release.version}',
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
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              release.notes,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
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
