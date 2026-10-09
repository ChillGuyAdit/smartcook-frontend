import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme_colors.dart';
import '../../service/api_service.dart';

/// A short announcement from the service, shown at the top of the home page
/// until it is closed (a new announcement shows again).
class NoticeBanner extends StatefulWidget {
  const NoticeBanner({super.key, this.fetch});

  /// Test seam; defaults to the public announcement endpoint.
  final Future<ApiResponse> Function()? fetch;

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner> {
  static const _kDismissed = 'notice_dismissed_id';
  String? _id;
  String? _text;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await (widget.fetch ??
          () => ApiService.get('/api/app/notice',
              useAuth: false, requireAppSession: false))();
      final data = res.success ? res.data : null;
      if (data is! Map) return;
      final id = data['id']?.toString();
      final text = data['text']?.toString().trim();
      if (id == null || text == null || text.isEmpty) return;
      String? dismissed;
      try {
        dismissed =
            (await SharedPreferences.getInstance()).getString(_kDismissed);
      } catch (_) {}
      if (dismissed == id || !mounted) return;
      setState(() {
        _id = id;
        _text = text;
      });
    } catch (_) {
      // an announcement is never worth an error
    }
  }

  Future<void> _close() async {
    final id = _id;
    setState(() => _text = null);
    if (id == null) return;
    try {
      (await SharedPreferences.getInstance()).setString(_kDismissed, id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.campaign_outlined,
                size: 20, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: context.colors.textPrimary),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded,
                size: 18, color: context.colors.textSecondary),
            onPressed: _close,
          ),
        ],
      ),
    );
  }
}
