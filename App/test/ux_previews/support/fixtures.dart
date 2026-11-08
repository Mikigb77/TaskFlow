// Realistic Spanish content for the previews: people, projects and days of
// tasks, placed relative to a fixed clock.
import 'package:agenda/models/capture_command.dart';
import 'package:agenda/models/capture_session.dart';
import 'package:agenda/models/checklist_item.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_draft.dart';
import 'package:agenda/models/task_list_info.dart';

/// The day the suite runs, fixed once for the whole run.
final DateTime previewToday = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}();

/// The clock seam's "now" (`calendarClockProvider`): 09:41 on that day, so
/// the morning is over and the day's appointments are still ahead.
final DateTime previewNow = previewToday.add(const Duration(hours: 9, minutes: 41));

/// [offset] days from today, at [hour]:[minute].
DateTime day(int offset, [int hour = 0, int minute = 0]) => DateTime(
  previewToday.year,
  previewToday.month,
  previewToday.day + offset,
  hour,
  minute,
);

/// `2026-10-21`.
String key(DateTime date) => Task.dateKey(date);

/// The next [weekday] at least [from] days away, so its label is a weekday,
/// never Hoy or Mañana.
DateTime next(int weekday, {int from = 2}) {
  var date = day(from);
  while (date.weekday != weekday) {
    date = DateTime(date.year, date.month, date.day + 1);
  }
  return date;
}

// ------------------------------------------------------------------ people

const me = 1, ana = 2, paul = 3, lucia = 4, jordi = 5, marta = 6, carlos = 7;

/// The signed-in account.
Map<String, dynamic> account({
  int? freeLeft,
  String? firstName,
  bool google = false,
  bool complimentary = false,
  int? storageMb,
}) => {
  'id': me,
  'email': 'maria.lopez@example.com',
  'timezone': 'Europe/Madrid',
  'first_name': ?firstName,
  if (google) 'google_linked': true,
  if (complimentary) 'complimentary_pro': true,
  if (storageMb != null)
    'storage': {
      'used_bytes': storageMb * 1024 * 1024,
      'limit_bytes': 200 * 1024 * 1024,
      'month_used_bytes': storageMb * 1024 * 1024,
      'month_limit_bytes': 500 * 1024 * 1024,
    },
  if (freeLeft != null)
    'free_voice': {
      'limit': 10,
      'left': freeLeft,
      'resets_at': DateTime.utc(previewToday.year, previewToday.month + 1)
          .toIso8601String(),
    },
};

// ---------------------------------------------------------------- projects

final matematicas = TaskListInfo(
  id: 'matematicas',
  name: 'Matemáticas',
  color: 'blue',
  version: 3,
  role: 'owner',
  shared: true,
  ownerId: me,
  people: const [
    ProjectMember(id: me, name: 'María', role: 'owner'),
    ProjectMember(id: ana, name: 'Ana', role: 'editor'),
    ProjectMember(id: paul, name: 'Paul', role: 'editor'),
  ],
);

/// A shared project with many people.
final excursion = TaskListInfo(
  id: 'excursion',
  name: 'Excursión de fin de curso',
  color: 'amber',
  version: 5,
  role: 'owner',
  shared: true,
  ownerId: me,
  people: const [
    ProjectMember(id: me, name: 'María', role: 'owner'),
    ProjectMember(id: ana, name: 'Ana', role: 'editor'),
    ProjectMember(id: paul, name: 'Paul', role: 'editor'),
    ProjectMember(id: lucia, name: 'Lucía', role: 'editor'),
    ProjectMember(id: jordi, name: 'Jordi', role: 'editor'),
    ProjectMember(id: marta, name: 'Marta', role: 'viewer'),
    ProjectMember(id: carlos, name: 'Carlos', role: 'viewer'),
  ],
);

final casa = TaskListInfo(id: 'casa', name: 'Casa', color: 'teal', version: 1);
final trabajo = TaskListInfo(
  id: 'trabajo',
  name: 'Trabajo',
  color: 'violet',
  version: 1,
);
final fisica = TaskListInfo(
  id: 'fisica',
  name: 'Física',
  color: 'rose',
  version: 1,
);

List<TaskListInfo> get allProjects => [matematicas, excursion, casa, trabajo];

// ------------------------------------------------------------------- tasks

/// An ordinary day: a few appointments, one done, one with no date.
List<Task> normalDay() => [
  Task(
    id: 1,
    title: 'Paseo por el parque',
    dueDate: day(0, 8, 30),
    priority: 1,
    isCompleted: true,
  ),
  Task(
    id: 2,
    title: 'Llamar al médico para pedir cita',
    dueDate: day(0, 10),
    priority: 2,
    notes: 'Preguntar por los resultados de los análisis.',
  ),
  Task(
    id: 3,
    title: 'Comer con Ana',
    dueDate: day(0, 13, 30),
    priority: 1,
  ),
  Task(
    id: 4,
    title: 'Recoger a los niños del colegio',
    dueDate: day(0, 17),
    priority: 3,
    reminderMinutes: 30,
  ),
  Task(
    id: 5,
    title: 'Clase de yoga',
    dueDate: day(0, 19, 30),
    priority: 1,
    recurrence: 'weekly',
  ),
  Task(id: 6, title: 'Comprar pilas para el mando', priority: 1),
  Task(
    id: 7,
    title: 'Pagar la factura de la luz',
    dueDate: day(2),
    hasTime: false,
    priority: 2,
  ),
  Task(
    id: 8,
    title: 'Repasar fracciones con Paul',
    dueDate: day(1, 18),
    priority: 1,
    listId: 'matematicas',
    assignment: 'member',
    assigneeId: paul,
    assigneeName: 'Paul',
  ),
];

/// A busy day: long titles, overlapping times, steps, projects and people.
List<Task> busyDay() => [
  ...normalDay(),
  Task(
    id: 20,
    title: 'Reunión con el tutor de Lucía para hablar del trimestre y de las notas',
    dueDate: day(0, 9),
    durationMinutes: 60,
    priority: 2,
  ),
  Task(
    id: 21,
    title: 'Enviar el presupuesto de la reforma de la cocina',
    dueDate: day(0, 11),
    priority: 3,
    listId: 'trabajo',
    deadline: day(1, 14),
    deadlineHasTime: true,
  ),
  Task(
    id: 22,
    title: 'Preparar la excursión',
    dueDate: day(0, 12),
    priority: 2,
    listId: 'excursion',
    assignment: 'group',
    checklist: [
      ChecklistItem(id: 'c1', title: 'Autorizaciones firmadas', completed: true),
      ChecklistItem(id: 'c2', title: 'Reservar el autobús'),
      ChecklistItem(id: 'c3', title: 'Lista de comida'),
    ],
  ),
  Task(
    id: 23,
    title: 'Farmacia: recoger la receta',
    dueDate: day(0, 16, 30),
    priority: 1,
  ),
  Task(
    id: 24,
    title: 'Corregir los ejercicios del tema 4',
    dueDate: day(0, 18),
    priority: 2,
    listId: 'matematicas',
    assignment: 'member',
    assigneeId: ana,
    assigneeName: 'Ana',
    createdBy: paul,
    createdByName: 'Paul',
  ),
  Task(
    id: 25,
    title: 'Llamar a la abuela',
    dueDate: day(0, 20, 30),
    priority: 1,
  ),
  Task(
    id: 26,
    title: 'Renovar el DNI',
    dueDate: day(-2),
    hasTime: false,
    priority: 3,
  ),
];

/// The tasks of the shared project «Matemáticas», by several people.
List<Task> sharedProjectTasks() => [
  Task(
    id: 30,
    title: 'Preparar el examen del tema 5',
    dueDate: day(3, 10),
    priority: 3,
    listId: 'matematicas',
    assignment: 'group',
    createdBy: me,
    createdByName: 'María',
  ),
  Task(
    id: 31,
    title: 'Corregir los ejercicios del tema 4',
    dueDate: day(0, 18),
    priority: 2,
    listId: 'matematicas',
    assignment: 'member',
    assigneeId: ana,
    assigneeName: 'Ana',
    createdBy: paul,
    createdByName: 'Paul',
  ),
  Task(
    id: 32,
    title: 'Hacer la ficha de repaso del tema 5',
    dueDate: day(2, 17),
    priority: 1,
    listId: 'matematicas',
    assignment: 'member',
    assigneeId: paul,
    assigneeName: 'Paul',
    createdBy: ana,
    createdByName: 'Ana',
  ),
  Task(
    id: 33,
    title: 'Fotocopias de geometría',
    priority: 1,
    listId: 'matematicas',
    assignment: 'unassigned',
    createdBy: paul,
    createdByName: 'Paul',
  ),
  Task(
    id: 34,
    title: 'Subir las notas',
    dueDate: day(-1),
    hasTime: false,
    priority: 2,
    listId: 'matematicas',
    assignment: 'member',
    assigneeId: me,
    assigneeName: 'María',
    isCompleted: true,
  ),
];

// ---------------------------------------------------------- what was said

/// A draft as the server sends it.
Map<String, dynamic> serverTask(
  String title, {
  DateTime? date,
  bool time = false,
  String? listId,
  String? newProject,
  String notes = '',
  List<String> questions = const [],
  List<Map<String, dynamic>> clarifications = const [],
  String assignment = 'personal',
  Map<String, String?> hints = const {},
  List<String> issues = const [],
}) => {
  'title': title,
  'due_date': date != null && time ? date.toUtc().toIso8601String() : null,
  'scheduled_date': date != null && !time ? key(date) : null,
  'priority': 1,
  'notes': notes,
  'questions': questions,
  if (clarifications.isNotEmpty) 'clarifications': clarifications,
  'list_id': listId,
  'assignment': assignment,
  'assignment_issues': issues,
  'assignment_hints': {'project': null, 'member': null, ...hints},
  'new_project': newProject,
  'project_suggestion': null,
};

CaptureDraft draft(
  String title, {
  DateTime? date,
  bool time = false,
  String? listId,
  String? newProject,
  String notes = '',
  List<String> questions = const [],
  List<Map<String, dynamic>> clarifications = const [],
  String transcript = 'Lo que dije',
}) => CaptureDraft.fromAI(
  TaskDraft.fromJson({
    ...serverTask(
      title,
      date: date,
      time: time,
      listId: listId,
      newProject: newProject,
      notes: notes,
      questions: questions,
      clarifications: clarifications,
    ),
    'transcript': transcript,
  }),
);

CaptureCommand command(Map<String, dynamic> json) =>
    CaptureCommand.fromServer({'issues': [], ...json})!;
