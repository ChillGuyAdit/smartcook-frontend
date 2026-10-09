import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'devices_page.dart';
import 'more_pages.dart';
import 'ops_api.dart';
import 'ops_widgets.dart';
import 'security_page.dart';
import 'server_page.dart';

/// Home of the console: a bottom bar with the sections this account may use.
/// Only the visible section is built, so a live feed stops when you leave it.
class OpsShell extends StatefulWidget {
  const OpsShell({super.key, required this.api, required this.me});
  final OpsApi api;
  final OpsMe me;

  @override
  State<OpsShell> createState() => _OpsShellState();
}

class _Tab {
  const _Tab(this.icon, this.label, this.build);
  final IconData icon;
  final String label;
  final Widget Function() build;
}

class _OpsShellState extends State<OpsShell> {
  int _index = 0;

  List<_Tab> get _tabs {
    final me = widget.me;
    final api = widget.api;
    return [
      if (me.can('monitor'))
        _Tab(
            Icons.monitor_heart_outlined, 'Server', () => ServerPage(api: api)),
      if (me.can('devices'))
        _Tab(Icons.smartphone_outlined, t('Perangkat', 'Devices'),
            () => DevicesPage(api: api, me: me)),
      if (me.can('restrict') || me.can('trail'))
        _Tab(Icons.shield_outlined, t('Keamanan', 'Security'),
            () => SecurityPage(api: api, me: me)),
      _Tab(Icons.apps_rounded, t('Lainnya', 'More'),
          () => _More(api: api, me: me)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final i = _index.clamp(0, tabs.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[i].label),
        actions: [
          IconButton(
            tooltip: t('Kembali ke aplikasi', 'Back to the app'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: KeyedSubtree(key: ValueKey(i), child: tabs[i].build()),
      // NavigationBar needs two destinations; a member with a single section
      // simply has no bar.
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => setState(() => _index = v),
              destinations: [
                for (final x in tabs)
                  NavigationDestination(icon: Icon(x.icon), label: x.label)
              ],
            ),
    );
  }
}

class _More extends StatelessWidget {
  const _More({required this.api, required this.me});
  final OpsApi api;
  final OpsMe me;

  @override
  Widget build(BuildContext context) {
    Widget item(
            IconData icon, String title, String sub, Widget Function() page) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => page())),
            child: Row(children: [
              Icon(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(sub,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: context.colors.textSecondary)),
                    ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (me.can('monitor'))
          item(
              Icons.insights_outlined,
              t('Ringkasan', 'Overview'),
              t('Angka utama dan galat per versi',
                  'Key numbers and errors by build'),
              () => OverviewPage(api: api)),
        if (me.can('people'))
          item(
              Icons.people_outline,
              t('Pengguna', 'People'),
              t('Cari akun, perangkat dan riwayat masuk',
                  'Find accounts, devices and sign-ins'),
              () => PeoplePage(api: api, me: me)),
        if (me.can('logs'))
          item(
              Icons.receipt_long_outlined,
              t('Log', 'Logs'),
              t('Galat dan peristiwa terbaru', 'Latest errors and events'),
              () => LogsPage(api: api)),
        if (me.can('members'))
          item(
              Icons.group_add_outlined,
              t('Tim', 'Team'),
              t('Anggota dan izin', 'Members and rights'),
              () => TeamPage(api: api, me: me)),
        if (me.can('notice'))
          item(
              Icons.campaign_outlined,
              t('Pengumuman', 'Announcement'),
              t('Banner di beranda aplikasi', 'Banner on the app home screen'),
              () => NoticeEditorPage(api: api)),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            t('Masuk sebagai ${me.role}', 'Signed in as ${me.role}'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
