import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme_colors.dart';

/// Units offered when adding or editing a fridge item.
const List<String> fridgeUnits = ['pcs', 'gram', 'kg', 'ml', 'liter'];

/// Unit chips + expiry date picker, shared by "add ingredient" and "edit
/// ingredient". The date is optional: "no date" is a real answer.
class FridgeDetailsFields extends StatelessWidget {
  const FridgeDetailsFields({
    super.key,
    required this.unit,
    required this.expiry,
    required this.onUnit,
    required this.onExpiry,
  });

  final String unit;
  final DateTime? expiry;
  final ValueChanged<String> onUnit;
  final ValueChanged<DateTime?> onExpiry;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: expiry != null && !expiry!.isBefore(today) ? expiry! : today,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) onExpiry(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final units =
        fridgeUnits.contains(unit) ? fridgeUnits : [...fridgeUnits, unit];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.unitLabel,
            style:
                TextStyle(fontSize: 12, color: context.colors.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final u in units)
              ChoiceChip(
                label: Text(u, style: const TextStyle(fontSize: 12)),
                selected: u == unit,
                showCheckmark: false,
                onSelected: (_) => onUnit(u),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(s.expiryDateLabel,
            style:
                TextStyle(fontSize: 12, color: context.colors.textSecondary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  expiry == null
                      ? s.pickDate
                      : MaterialLocalizations.of(context)
                          .formatMediumDate(expiry!),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (expiry != null)
              IconButton(
                tooltip: s.clearDate,
                onPressed: () => onExpiry(null),
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ],
    );
  }
}
