import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/journal/domain/journal_activity.dart';
import 'package:quitepaper/core/journal/domain/journal_moment.dart';
import 'package:quitepaper/core/journal/domain/journal_mood.dart';
import 'package:quitepaper/core/journal/domain/journal_weather.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  group('JournalActivity domain tests', () {
    test('standard presets are configured with Phosphor icons', () {
      expect(JournalActivity.standardPresets, isNotEmpty);
      for (final activity in JournalActivity.standardPresets) {
        expect(activity.id, isNotEmpty);
        expect(activity.label, isNotEmpty);
        expect(activity.iconKey, isNotEmpty);
        expect(activity.icon.fontFamily, equals(PhosphorIconsRegular.fontFamily));
      }

      final exercise = JournalActivity.standardPresets.firstWhere((a) => a.id == 'exercise');
      expect(exercise.icon, equals(PhosphorIconsRegular.personSimpleRun));
      expect(exercise.iconKey, equals('person-simple-run'));

      final reading = JournalActivity.standardPresets.firstWhere((a) => a.id == 'reading');
      expect(reading.icon, equals(PhosphorIconsRegular.bookOpen));
      expect(reading.iconKey, equals('book-open'));
    });

    test('toJson and fromJson serialize and resolve iconKey with TagIconRegistry', () {
      final activity = JournalActivity(
        id: 'climbing',
        label: 'Climbing',
        icon: PhosphorIconsRegular.mountains,
        iconKey: 'mountains',
        isCustom: true,
      );

      final json = activity.toJson();
      expect(json['id'], equals('climbing'));
      expect(json['label'], equals('Climbing'));
      expect(json['iconKey'], equals('mountains'));
      expect(json['isCustom'], isTrue);

      final parsed = JournalActivity.fromJson(json);
      expect(parsed.id, equals('climbing'));
      expect(parsed.label, equals('Climbing'));
      expect(parsed.iconKey, equals('mountains'));
      expect(parsed.icon, equals(PhosphorIconsRegular.mountains));
      expect(parsed.isCustom, isTrue);
    });

    test('fromJson falls back to Phosphor star when iconKey is unknown', () {
      final json = {
        'id': 'mystery',
        'label': 'Mystery Activity',
        'iconKey': 'non-existent-icon-name-xyz',
      };

      final parsed = JournalActivity.fromJson(json);
      expect(parsed.id, equals('mystery'));
      expect(parsed.icon, equals(PhosphorIconsRegular.star));
    });
  });

  group('JournalMoment domain tests', () {
    test('all moments use Phosphor icons', () {
      expect(JournalMoment.all.length, equals(10));
      for (final m in JournalMoment.all) {
        expect(m.key, isNotEmpty);
        expect(m.label, isNotEmpty);
        expect(m.emoji, isNotEmpty);
        expect(m.icon.fontFamily, equals(PhosphorIconsRegular.fontFamily));
      }

      expect(JournalMoment.fromKey('ordinary')?.icon, equals(PhosphorIconsRegular.coffee));
      expect(JournalMoment.fromKey('travel')?.icon, equals(PhosphorIconsRegular.airplane));
      expect(JournalMoment.fromKey('work')?.icon, equals(PhosphorIconsRegular.briefcase));
      expect(JournalMoment.fromKey('family')?.icon, equals(PhosphorIconsRegular.house));
      expect(JournalMoment.fromKey('social')?.icon, equals(PhosphorIconsRegular.chatsTeardrop));
      expect(JournalMoment.fromKey('health')?.icon, equals(PhosphorIconsRegular.heart));
      expect(JournalMoment.fromKey('creative')?.icon, equals(PhosphorIconsRegular.palette));
      expect(JournalMoment.fromKey('celebration')?.icon, equals(PhosphorIconsRegular.confetti));
      expect(JournalMoment.fromKey('difficult')?.icon, equals(PhosphorIconsRegular.cloudRain));
      expect(JournalMoment.fromKey('reflection')?.icon, equals(PhosphorIconsRegular.sparkle));
    });

    test('fromKey resolves normalized and hypenated keys', () {
      expect(JournalMoment.fromKey('TRAVEL')?.key, equals('travel'));
      expect(JournalMoment.fromKey('  social  ')?.key, equals('social'));
      expect(JournalMoment.fromKey(null), isNull);
      expect(JournalMoment.fromKey('non-existent'), isNull);
    });
  });

  group('JournalWeather domain tests', () {
    test('resolves Phosphor icons for WMO codes', () {
      expect(JournalWeather.iconForWmoCode(0), equals(PhosphorIconsRegular.sun));
      expect(JournalWeather.iconForWmoCode(1), equals(PhosphorIconsRegular.cloudSun));
      expect(JournalWeather.iconForWmoCode(45), equals(PhosphorIconsRegular.cloudFog));
      expect(JournalWeather.iconForWmoCode(61), equals(PhosphorIconsRegular.cloudRain));
      expect(JournalWeather.iconForWmoCode(71), equals(PhosphorIconsRegular.snowflake));
      expect(JournalWeather.iconForWmoCode(95), equals(PhosphorIconsRegular.cloudLightning));
      expect(JournalWeather.iconForWmoCode(999), equals(PhosphorIconsRegular.cloud));
    });
  });

  group('JournalMood domain tests', () {
    test('levels contains 10 mood definitions', () {
      expect(JournalMood.levels.length, equals(10));
      for (int i = 0; i < 10; i++) {
        expect(JournalMood.levels[i].level, equals(i + 1));
      }
    });

    test('fromLevel parses ints and numeric strings', () {
      expect(JournalMood.fromLevel(1)?.label, equals('Terrible'));
      expect(JournalMood.fromLevel('5')?.label, equals('Neutral'));
      expect(JournalMood.fromLevel(10)?.label, equals('Ecstatic'));
      expect(JournalMood.fromLevel(0), isNull);
      expect(JournalMood.fromLevel(11), isNull);
      expect(JournalMood.fromLevel('invalid'), isNull);
      expect(JournalMood.fromLevel(null), isNull);
    });
  });
}
