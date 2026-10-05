import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jx3_tasks/models/task_models.dart';
import 'package:jx3_tasks/theme/tag_colors.dart';

void main() {
  test('game color survives editing and backup round trips', () {
    const game = Game(id: 'game', name: '游戏');
    final edited = game.copyWith(color: TagColors.colorAt(7));
    final restored = Game.fromJson(edited.toJson());
    expect(restored.color, edited.color);
    expect(restored.copyWith(name: '新名称').color, edited.color);
    expect(restored.copyWith(color: 0xff2f7d72).color, 0xff2f7d72);
  });

  test('all selectable colors have readable light and dark variants', () {
    for (var index = 0; index < TagColors.names.length; index++) {
      for (final brightness in Brightness.values) {
        final colors = TagColors.forLabel('游戏', brightness,
            color: TagColors.colorAt(index));
        final a = colors.foreground.computeLuminance();
        final b = colors.background.computeLuminance();
        final ratio = a > b ? (a + 0.05) / (b + 0.05)
            : (b + 0.05) / (a + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5));
        expect(TagColors.forLabel('改名', brightness,
            color: TagColors.colorAt(index)), colors);
      }
    }
    expect(TagColors.forLabel('游戏', Brightness.light),
        TagColors.forLabel('游戏', Brightness.light));
  });
}
