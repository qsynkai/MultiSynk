enum TaskPriority { none, low, medium, high, urgent }
enum TaskCategory { financial, vehicle, personal, work, health, other }

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskPriority? aiPriority;
  final String? aiReason;
  final TaskCategory category;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool isDone;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.priority = TaskPriority.none,
    this.aiPriority,
    this.aiReason,
    this.category = TaskCategory.personal,
    required this.createdAt,
    this.dueDate,
    this.isDone = false,
  });

  TaskPriority get effectivePriority => aiPriority ?? priority;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'priority': priority.name,
    'ai_priority': aiPriority?.name,
    'ai_reason': aiReason,
    'category': category.name,
    'created_at': createdAt.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'is_done': isDone ? 1 : 0,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'],
    title: map['title'],
    description: map['description'],
    priority: TaskPriority.values.byName(map['priority'] ?? 'none'),
    aiPriority: map['ai_priority'] != null
        ? TaskPriority.values.byName(map['ai_priority'])
        : null,
    aiReason: map['ai_reason'],
    category: TaskCategory.values.byName(map['category'] ?? 'personal'),
    createdAt: DateTime.parse(map['created_at']),
    dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
    isDone: map['is_done'] == 1,
  );

  Task copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    TaskPriority? aiPriority,
    String? aiReason,
    TaskCategory? category,
    DateTime? dueDate,
    bool? isDone,
  }) => Task(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    aiPriority: aiPriority ?? this.aiPriority,
    aiReason: aiReason ?? this.aiReason,
    category: category ?? this.category,
    createdAt: createdAt,
    dueDate: dueDate ?? this.dueDate,
    isDone: isDone ?? this.isDone,
  );
}
