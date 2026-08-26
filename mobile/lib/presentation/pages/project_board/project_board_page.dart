import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/providers/project_task_provider.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/section_header.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProjectBoardPage extends StatelessWidget {
  const ProjectBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<ProjectTaskProvider>();

    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task Board',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status pengerjaan UI EggGym untuk kebutuhan demo mobile.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _CountCard(
                  label: 'Done',
                  count: tasks.count(TaskStatus.done),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountCard(
                  label: 'Progress',
                  count: tasks.count(TaskStatus.inProgress),
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountCard(
                  label: 'Todo',
                  count: tasks.count(TaskStatus.todo),
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _TaskSection(
            title: 'Sedang Dikerjakan',
            color: AppColors.accent,
            tasks: tasks.byStatus(TaskStatus.inProgress),
          ),
          const SizedBox(height: 24),
          _TaskSection(
            title: 'Sudah Selesai',
            color: AppColors.success,
            tasks: tasks.byStatus(TaskStatus.done),
          ),
          const SizedBox(height: 24),
          _TaskSection(
            title: 'Belum Dikerjakan',
            color: AppColors.error,
            tasks: tasks.byStatus(TaskStatus.todo),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.color,
    required this.tasks,
  });

  final String title;
  final Color color;
  final List<ProjectTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: '${tasks.length} task',
        ),
        const SizedBox(height: 16),
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EggCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.scope,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    task.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
