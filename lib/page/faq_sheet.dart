import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_theme_colors.dart';
import '../service/api_service.dart';

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});

  factory FaqItem.fromJson(Map<String, dynamic> json, bool isEnglish) {
    // Both languages ship with every item; pick by device language and fall
    // back to Indonesian if a translation is ever empty.
    final q = isEnglish ? (json['question_en'] ?? '') : (json['question'] ?? '');
    final a = isEnglish ? (json['answer_en'] ?? '') : (json['answer'] ?? '');
    return FaqItem(
      question: (q.isNotEmpty ? q : json['question'] ?? '').toString(),
      answer: (a.isNotEmpty ? a : json['answer'] ?? '').toString(),
    );
  }
}

/// FAQ, served by the backend so the wording can be fixed without shipping a
/// release. Both languages come from the same item.
Future<void> showFaqSheet(BuildContext context) async {
  final s = stringsFor(Localizations.localeOf(context));
  final isEnglish = Localizations.localeOf(context).languageCode == 'en';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                  Text(
                    s.faq,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: ctx.colors.textSecondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<FaqItem>>(
                future: _fetchFaq(isEnglish),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.faqLoadFailed,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ctx.colors.textSecondary),
                        ),
                      ),
                    );
                  }
                  final items = snapshot.data ?? const <FaqItem>[];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        s.faqLoadFailed,
                        style: TextStyle(color: ctx.colors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _FaqCard(item: items[index]),
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

Future<List<FaqItem>> _fetchFaq(bool isEnglish) async {
  final res = await ApiService.get('/api/help/faq');
  if (!res.success || res.data is! Map<String, dynamic>) {
    throw StateError('faq unavailable');
  }
  final raw = (res.data as Map<String, dynamic>)['items'];
  if (raw is! List) throw StateError('faq malformed');
  return raw
      .whereType<Map<String, dynamic>>()
      .map((e) => FaqItem.fromJson(e, isEnglish))
      .toList();
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.item});

  final FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.question,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.answer,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contact details come from env on the server; a null value means the app
/// hides that button rather than showing an empty row.
class ContactInfo {
  final String? email;
  final String? whatsapp;
  final String? hours;

  const ContactInfo({this.email, this.whatsapp, this.hours});

  bool get isEmpty => email == null && whatsapp == null;

  factory ContactInfo.fromJson(Map<String, dynamic> json) => ContactInfo(
        email: json['email'] as String?,
        whatsapp: json['whatsapp'] as String?,
        hours: json['hours'] as String?,
      );
}
