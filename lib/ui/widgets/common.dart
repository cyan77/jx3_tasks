import 'package:flutter/material.dart';

import '../../models/task_models.dart';
import '../../theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader(
      {required this.title,
      this.subtitle,
      this.titleAction,
      this.action,
      super.key});
  final String title;
  final String? subtitle;
  final Widget? titleAction;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final heading = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (titleAction != null) ...[
                      const SizedBox(width: 8),
                      Flexible(child: titleAction!),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ],
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
              child: compact
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: heading),
                        if (action != null) ...[
                          const SizedBox(width: 12),
                          action!,
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: heading),
                        if (action != null) action!,
                      ],
                    ),
            );
          },
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (trailing != null) trailing!
      ]);
}

class ProgressLine extends StatelessWidget {
  const ProgressLine(
      {required this.value, this.color = AppTheme.accent, super.key});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 5,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: color),
      );
}

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({required this.character, this.size = 30, super.key});
  final Character character;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Color(character.color).withAlpha(24),
            border: Border.all(color: Color(character.color).withAlpha(85)),
            shape: BoxShape.circle),
        child: Text(
            character.name.isEmpty ? '?' : character.name.substring(0, 1),
            style: TextStyle(
                fontSize: size * .38,
                fontWeight: FontWeight.w700,
                color: Color(character.color))),
      );
}

class TaskCheck extends StatelessWidget {
  const TaskCheck({required this.checked, required this.onTap, super.key});
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              color: checked
                  ? AppTheme.accent
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                  color: checked ? AppTheme.accent : const Color(0xffb9c2c8)),
              borderRadius: BorderRadius.circular(4)),
          child: checked
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      );
}

String dueLabel(DateTime? date) {
  if (date == null) return '';
  return '${date.month}/${date.day} 截止';
}
