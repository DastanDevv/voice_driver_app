import 'package:flutter_test/flutter_test.dart';

import 'package:voice_driver_mobile/core/nlp/command_splitter.dart';

void main() {
  const splitter = CommandSplitter();

  group('CommandSplitter', () {
    test('одна команда — один сегмент', () {
      expect(
        splitter.split('создай задачу купить хлеб'),
        ['создай задачу купить хлеб'],
      );
    });

    test('"а потом" разделяет на два сегмента', () {
      expect(
        splitter.split('покажи задачи а потом включи тёмную тему'),
        ['покажи задачи', 'включи тёмную тему'],
      );
    });

    test('"и" перед глаголом — разделитель', () {
      expect(
        splitter.split('создай задачу купить хлеб и удали задачу презентацию'),
        ['создай задачу купить хлеб', 'удали задачу презентацию'],
      );
    });

    test('"и" внутри существительного не разделяет', () {
      expect(
        splitter.split('создай задачу купить хлеб и молоко'),
        ['создай задачу купить хлеб и молоко'],
      );
    });

    test('три команды через "а потом" и "также"', () {
      final r = splitter.split(
        'создай задачу X а потом удали задачу Y также покажи задачи',
      );
      expect(r.length, 3);
      expect(r[0], contains('создай'));
      expect(r[1], contains('удали'));
      expect(r[2], contains('покажи'));
    });

    test('пустой ввод даёт пустой список', () {
      expect(splitter.split(''), isEmpty);
      expect(splitter.split('   '), isEmpty);
    });
  });
}
