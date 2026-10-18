import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../models/task.dart';
import '../services/ai_service.dart';

class TaskState {
  final List<Task> tasks;
  final bool isLoading;
  final bool isAnalyzing;

  const TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.isAnalyzing = false,
  });

  List<Task> get pendingTasks => tasks.where((t) => !t.isDone).toList()
    ..sort((a, b) => b.effectivePriority.index.compareTo(a.effectivePriority.index));

  List<Task> get doneTasks => tasks.where((t) => t.isDone).toList();

  TaskState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    bool? isAnalyzing,
  }) => TaskState(
    tasks: tasks ?? this.tasks,
    isLoading: isLoading ?? this.isLoading,
    isAnalyzing: isAnalyzing ?? this.isAnalyzing,
  );
}

class TaskNotifier extends StateNotifier<TaskState> {
  TaskNotifier() : super(const TaskState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final tasks = await DatabaseHelper.instance.getTasks(includeDone: true);
    state = TaskState(tasks: tasks);
  }

  Future<void> addTask(Task task) async {
    await DatabaseHelper.instance.insertTask(task);
    await load();
  }

  Future<void> toggleDone(Task task) async {
    await DatabaseHelper.instance.updateTask(task.copyWith(isDone: !task.isDone));
    await load();
  }

  Future<void> deleteTask(String id) async {
    await DatabaseHelper.instance.deleteTask(id);
    await load();
  }

  Future<void> analyzeWithAI() async {
    final pending = state.pendingTasks;
    if (pending.isEmpty) return;

    state = state.copyWith(isAnalyzing: true);
    final analyzed = await AiService.analyzePriorities(pending);

    for (final task in analyzed) {
      await DatabaseHelper.instance.updateTask(task);
    }

    await load();
    state = state.copyWith(isAnalyzing: false);
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>(
  (ref) => TaskNotifier(),
);
