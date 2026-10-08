import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcook/core/l10n/strings.dart';

/// Regression guard for "I changed the language but half the app did not
/// change": user-visible text in screens must come from the string table
/// (`context.s.x`), never from a literal in the widget code.
void main() {
  // Literals that are intentionally the same in every language.
  const allowed = {
    'SmartChef', // product name
    'Email',
    'Password',
    'Global',
    'Total',
    'smartcook@gmail.com', // example address in a hint
    'Jagung Sayur Kentang Bowl', // sample card content
    'SmartCook',
  };

  final textLiteral = RegExp(
    r"""(?:\bText\(\s*|\b(?:hintText|labelText|helperText|errorText)\s*:\s*)(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")""",
  );

  test('screens contain no hard-coded user-visible text', () {
    final offenders = <String>[];
    for (final dir in ['lib/page', 'lib/auth']) {
      for (final f in Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lines = f.readAsLinesSync();
        final src = lines.join('\n');
        for (final m in textLiteral.allMatches(src)) {
          final text = m.group(1) ?? m.group(2) ?? '';
          // Only the words outside ${...} / $name interpolations are visible copy.
          final visible = text
              .replaceAll(RegExp(r'\$\{[^}]*\}?'), '')
              .replaceAll(RegExp(r'\$\w+'), '');
          if (!RegExp(r'[A-Za-z]{3}').hasMatch(visible)) continue; // numbers, symbols
          if (allowed.any((a) => text == a || text.startsWith(a))) continue;
          final line = src.substring(0, m.start).split('\n').length;
          offenders.add('${f.path}:$line  "$text"');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Move these into lib/core/l10n/strings.dart (StrId + StrEn):\n${offenders.join('\n')}');
  });

  test('every translated string differs between Indonesian and English where it should', () {
    // Sanity on a sample: the two tables are not accidentally identical.
    const id = StrId();
    const en = StrEn();
    expect(id.signInLabel, isNot(en.signInLabel));
    expect(id.passwordMin6, isNot(en.passwordMin6));
    expect(id.noSavedRecipes, isNot(en.noSavedRecipes));
    expect(id.fridgeIntro, isNot(en.fridgeIntro));
    expect(id.greeting('Adam'), contains('Adam'));
    expect(en.greeting('Adam'), contains('Adam'));
    expect(id.greeting('Adam'), isNot(en.greeting('Adam')));
    expect(en.savedNOfM(2, 5), contains('2'));
    expect(en.savedNOfM(2, 5), contains('5'));
    expect(en.recipeMeta(120, 30), '120 kcal • 30m');
    expect(id.recipeMeta(120, 30), '120 Kal • 30m');
  });

  test('parametrised strings keep their values in both languages', () {
    for (final s in <Str>[const StrId(), const StrEn()]) {
      expect(s.otpExpiresIn('04:59'), contains('04:59'));
      expect(s.deleteIngredientBody('Ayam'), contains('Ayam'));
      expect(s.noResultsFor('nasi'), contains('nasi'));
      expect(s.newIngredientNote('Bawang', 'sayur'), allOf(contains('Bawang'), contains('sayur')));
      expect(s.ingredientsAddedToFridge(3), contains('3'));
      expect(s.couldNotOpen('https://x.y'), contains('https://x.y'));
      expect(s.lessThanDays(3), contains('3'));
    }
  });
}
