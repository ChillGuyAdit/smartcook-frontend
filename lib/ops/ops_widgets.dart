import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import '../core/theme/language_controller.dart';

/// Two-language text for this module (it only ever shows to a few people, so
/// it keeps its wording next to the code instead of the shared string table).
String t(String id, String en) {
  try {
    return LanguageController.instance.locale.languageCode == 'en' ? en : id;
  } catch (_) {
    return id;
  }
}

String fmtBytes(num? b) {
  if (b == null) return '-';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${u[i]}';
}

String fmtRate(num? bps) => bps == null ? '-' : '${fmtBytes(bps)}/s';

String fmtPct(num? v, {int digits = 0}) =>
    v == null ? '-' : '${v.toStringAsFixed(digits)}%';

String fmtDuration(num? seconds) {
  if (seconds == null) return '-';
  final s = seconds.toInt();
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s % 60}s';
  return '${s}s';
}

/// "5 s ago", "3 min ago"... for a timestamp (ISO string or epoch millis).
String ago(dynamic when, {DateTime? now}) {
  DateTime? d;
  if (when is String) d = DateTime.tryParse(when)?.toLocal();
  if (when is num) d = DateTime.fromMillisecondsSinceEpoch(when.toInt());
  if (d == null) return '-';
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inSeconds < 5) return t('baru saja', 'just now');
  if (diff.inSeconds < 60)
    return t('${diff.inSeconds} dtk lalu', '${diff.inSeconds}s ago');
  if (diff.inMinutes < 60)
    return t('${diff.inMinutes} mnt lalu', '${diff.inMinutes} min ago');
  if (diff.inHours < 48)
    return t('${diff.inHours} jam lalu', '${diff.inHours} h ago');
  return t('${diff.inDays} hari lalu', '${diff.inDays} d ago');
}

num? numOf(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);

/// Colour for a load percentage: calm, busy, saturated.
Color loadColor(num? pct) {
  final p = pct ?? 0;
  if (p >= 85) return const Color(0xFFE53935);
  if (p >= 60) return const Color(0xFFFB8C00);
  return const Color(0xFF43A047);
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: context.colors.textSecondary)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Rounded card used by every panel.
class Panel extends StatelessWidget {
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap, child: card);
  }
}

/// Big number + caption + optional sparkline: the building block of the live view.
class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.series,
    this.color,
    this.seriesMax,
  });

  final String label;
  final String value;
  final String? sub;
  final List<double>? series;
  final Color? color;
  final double? seriesMax;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF43A047);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary)),
          ],
          if (series != null && series!.length > 1) ...[
            const SizedBox(height: 8),
            SizedBox(
                height: 38,
                width: double.infinity,
                child: Sparkline(values: series!, color: c, max: seriesMax)),
          ],
        ],
      ),
    );
  }
}

/// Thin horizontal meter with the share filled in.
class BarMeter extends StatelessWidget {
  const BarMeter(
      {super.key, required this.fraction, this.color, this.height = 8});
  final double fraction;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: context.colors.border),
          FractionallySizedBox(
            widthFactor: f,
            child:
                Container(height: height, color: color ?? loadColor(f * 100)),
          ),
        ],
      ),
    );
  }
}

/// Minimal line chart: values left to right, auto-scaled unless [max] is given.
class Sparkline extends StatelessWidget {
  const Sparkline(
      {super.key, required this.values, required this.color, this.max});
  final List<double> values;
  final Color color;
  final double? max;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SparkPainter(values, color, max));
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.max);
  final List<double> values;
  final Color color;
  final double? max;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final top = max ?? math.max(1.0, values.reduce(math.max));
    final dx = size.width / (values.length - 1);
    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final y = size.height - (values[i].clamp(0, top) / top) * size.height;
      final x = i * dx;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color || old.max != max;
}

/// Keeps the last [capacity] numbers of a stream (for the charts).
class Rolling {
  Rolling([this.capacity = 120]);
  final int capacity;
  final List<double> items = [];

  void add(num? v) {
    items.add((v ?? 0).toDouble());
    if (items.length > capacity) items.removeAt(0);
  }

  void addAll(Iterable<num?> list) {
    for (final v in list) {
      add(v);
    }
  }

  List<double> get values => List<double>.unmodifiable(items);
}

/// A small pill: status dot + text.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary))),
      );
}
