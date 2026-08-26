import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/domain/repositories/demo_repository.dart';
import 'package:flutter/foundation.dart';

class ProjectTaskProvider extends ChangeNotifier {
  ProjectTaskProvider(this._repository) {
    _tasks = _repository.getProjectTasks();
  }

  final DemoRepository _repository;
  late final List<ProjectTask> _tasks;

  List<ProjectTask> get tasks => List.unmodifiable(_tasks);

  List<ProjectTask> byStatus(TaskStatus status) {
    return _tasks
        .where((task) => task.status == status)
        .toList(growable: false);
  }

  int count(TaskStatus status) => byStatus(status).length;
}
