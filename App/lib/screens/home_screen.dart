import 'dart:async';
import 'dart:math' as math;
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_list.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/notes_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialFilter = 0,
    this.isRoot = true,
    this.listId,
    this.person,
    this.landing = const {},
  });
  final int initialFilter;
  final bool isRoot;
  final String? listId;

  /// The person a project page opens on, as a search for their tasks
  /// found them: their chip, or `Para mí` for the account itself. Anyone
  /// without a chip there (a viewer, someone who left) opens on `Todas`.
  final int? person;

  /// Tasks just saved that this page, opened for them, lights once they
  /// show: a project made by voice with its new tasks.
  final Set<int> landing;
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';
  final _search = TextEditingController();
  late int _filter = widget.initialFilter;
  String? _label;
  // A project page shows all of its tasks until `Para mí` is chosen here;
  // the choice stays on this page.
  bool _team = true;
  // A shared project page can show one person's tasks instead: those
  // assigned to them.
  int? _person;
  final _page = GlobalKey();
  final _nested = GlobalKey<NestedScrollViewState>();
  // Tasks just saved from capture opened here: waiting to appear, then shown
  // and highlighted.
  late Set<int> _landingIds = widget.landing;
  Set<int> _landedIds = {};
  bool _highlight = false;
  Timer? _highlightTimer;
  final _landedRow = GlobalKey();
  // Room under the last row, grown to the save message's height so a new
  // task at the end can still scroll clear of it.
  double _listEnd = 100;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    if (person == null || widget.listId == null) return;
    if (person == ref.read(authProvider).account?.id) {
      // `Para mí` only where its chip shows: on a shared project.
      _team = !(ref.read(taskListsProvider).valueOrNull ?? []).any(
        (p) => p.id == widget.listId && p.shared,
      );
    } else {
      _person = person;
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// The person whose tasks this project page shows, while they can still
  /// be chosen: someone who left takes their filter with them.
  int? get _personShown => _personChip?.id;

  /// The person behind [_personShown], whose name their chip shows.
  ProjectMember? get _personChip {
    final project = (ref.read(taskListsProvider).valueOrNull ?? [])
        .where((p) => p.id == widget.listId)
        .firstOrNull;
    final people = projectPeopleToFilter(
      project,
      ref.read(authProvider).account?.id,
    );
    return people.where((p) => p.id == _person).firstOrNull;
  }

  /// The open tasks this page lists with the given search and filters.
  /// [everyone] leaves out a project page's `Para mí` and person.
  List<Task> _visible(
    List<Task> all, {
    required int filter,
    required String query,
    required String? label,
    bool everyone = false,
    ProjectScope? global,
  }) {
    final scope = everyone && widget.listId != null
        ? ProjectScope(projectId: widget.listId, team: true)
        : _scope(global ?? ref.read(projectScopeProvider));
    final person = everyone ? null : _personShown;
    final projects = ref.read(taskListsProvider).valueOrNull ?? [];
    final accountId = ref.read(authProvider).account?.id;
    final now = DateTime.now();
    final overdue = filter == 1
        ? all.map((task) => task.overdueOn(now)).whereType<Task>().toSet()
        : <Task>{};
    return all
        .map((task) => task.nextOpenOccurrence())
        .whereType<Task>()
        // A one-off overdue task is already its own next occurrence.
        .followedBy(overdue.where((task) => task.isRecurring))
        .where(
          (task) =>
              !task.isCompleted &&
              taskInProjectScope(task, scope, accountId, projects) &&
              (person == null ||
                  (task.assignment == 'member' && task.assigneeId == person)) &&
              (label == null || task.labels.contains(label)) &&
              (filter == 0 ||
                  (filter == 3 && task.dueDate == null) ||
                  (filter == 2 && task.priority == 3) ||
                  (filter == 1 &&
                      (overdue.contains(task) ||
                          DateUtils.isSameDay(task.displayDate, now)))) &&
              matchesSearch(
                '${task.title} ${task.notes ?? ''} ${task.labels.join(' ')} ${task.checklist.map((item) => item.title).join(' ')}',
                query,
              ),
        )
        .toList();
  }

  /// What this page lists: its own project and `Para mí` choice, or else
  /// the app-wide ones.
  ProjectScope _scope(ProjectScope global) => widget.listId == null
      ? global
      : ProjectScope(projectId: widget.listId, team: _team);

  /// Capture, or the form, opened here saved [focus]'s tasks. If the search
  /// or a filter would hide them, clear it, so they are on screen every
  /// time: on a project page, `Para mí` and a person too, when need be;
  /// elsewhere the app-wide `Para mí`, then the project filter.
  void _land(CalendarFocus focus) {
    final all = ref.read(taskProvider).valueOrNull ?? [];
    bool lists(List<Task> tasks) =>
        tasks.any((task) => focus.taskIds.contains(task.id));
    final global = ref.read(projectScopeProvider);
    final wider = widget.listId != null
        ? global
        : scopeShowing(
            all.where((task) => focus.taskIds.contains(task.id)),
            global,
            ref.read(authProvider).account?.id,
            ref.read(taskListsProvider).valueOrNull ?? [],
          );
    var scope = global;
    setState(() {
      if (!lists(
        _visible(all, filter: _filter, query: _query, label: _label),
      )) {
        for (final (clear, everyone, widen) in [
          (true, false, false),
          if (widget.listId != null) (true, true, false),
          if (!identical(wider, global)) ...[
            (false, false, true),
            (true, false, true),
          ],
        ]) {
          if (!lists(
            _visible(
              all,
              filter: clear && widget.isRoot ? 0 : _filter,
              query: clear ? '' : _query,
              label: clear ? null : _label,
              everyone: everyone,
              global: widen ? wider : global,
            ),
          )) {
            continue;
          }
          if (clear) {
            _search.clear();
            _query = '';
            _label = null;
            if (widget.isRoot) _filter = 0;
          }
          if (everyone) {
            _team = true;
            _person = null;
          }
          if (widen) scope = wider;
          break;
        }
      }
      _landingIds = focus.taskIds;
      _landedIds = {};
      _highlight = false;
      _highlightTimer?.cancel();
    });
    if (!identical(scope, global)) {
      ref.read(projectScopeProvider.notifier).state = scope;
      ref.read(scopeWideningProvider.notifier).state = ScopeWidening(
        focus,
        global,
        scope,
      );
    }
  }

  /// Brings the first new row into view, clear of the save message, then
  /// lets its highlight fade.
  Future<void> _reveal() async {
    final instant = MediaQuery.disableAnimationsOf(context);
    for (var i = 0; i < 20 && mounted; i++) {
      final clearance = _messageClearance();
      if (clearance != null && clearance > _listEnd) {
        setState(() => _listEnd = clearance);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      final need = _shortfall();
      if (need != null) {
        if (need != 0) {
          await _scrollBy(need, instant);
          await WidgetsBinding.instance.endOfFrame;
          // Correct once if the move fell short, as when rows reflow.
          final left = mounted ? _shortfall() : null;
          if (left != null && left.abs() >= 1) await _scrollBy(left, instant);
        }
        break;
      }
      // Rows out of view are only built once scrolled near: start from the
      // top, then move down a screen at a time.
      final inner = _nested.currentState?.innerController;
      if (inner == null || !inner.hasClients) break;
      final position = inner.position;
      if (i > 0 && position.pixels >= position.maxScrollExtent) break;
      inner.jumpTo(
        i == 0
            ? 0
            : math.min(
                position.pixels + position.viewportDimension,
                position.maxScrollExtent,
              ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlight = false);
    });
  }

  /// How far the page must scroll for the new row to show whole, clear of
  /// the save message under it: 0 when it already does, null while it isn't
  /// laid out. Measured on screen, as the list sits under the header.
  double? _shortfall() {
    final row = _landedRow.currentContext?.findRenderObject();
    final page = _nested.currentContext?.findRenderObject();
    if (row is! RenderBox || !row.hasSize || !row.attached) return null;
    if (page is! RenderBox || !page.hasSize) return null;
    final visible = page.localToGlobal(Offset.zero) & page.size;
    final rowRect = row.localToGlobal(Offset.zero) & row.size;
    if (rowRect.top < visible.top) return rowRect.top - visible.top;
    final need =
        rowRect.bottom -
        visible.bottom +
        math.max(88, _messageClearance() ?? 0);
    // Never past the row's top, so its top always shows.
    return need <= 0 ? 0 : math.min(need, rowRect.top - visible.top);
  }

  /// How much of the page's foot the save message shown over it takes, with
  /// a gap: it can be taller than the usual clearance, as with long text or
  /// large type. Read from its height, which is final while it fades in.
  double? _messageClearance() {
    RenderBox? message;
    void visit(Element element) {
      // The list can't hold the message, so skip its rows.
      if (message != null || element.widget.key == _nested) return;
      if (element.widget is SnackBar) {
        final box = element.findRenderObject();
        if (box is RenderBox && box.hasSize) message = box;
        return;
      }
      element.visitChildren(visit);
    }

    _page.currentContext?.visitChildElements(visit);
    final box = message;
    if (box == null || box.size.height == 0) return null;
    return box.size.height + 8;
  }

  /// Scrolls the header first, then the list, by [need] pixels in all.
  Future<void> _scrollBy(double need, bool instant) async {
    final nested = _nested.currentState;
    if (nested == null) return;
    final outer = nested.outerController;
    final inner = nested.innerController;
    if (!outer.hasClients || !inner.hasClients) return;
    final header = outer.position;
    final total = header.pixels + inner.position.pixels + need;
    final (controller, target) = total <= header.maxScrollExtent
        ? (outer, total)
        : (inner, total - header.maxScrollExtent);
    final position = controller.position;
    final offset = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (offset == position.pixels) return;
    if (instant) {
      controller.jumpTo(offset);
    } else {
      await controller.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CalendarFocus?>(calendarFocusProvider, (_, focus) {
      if (focus != null && identical(focus.page, this)) _land(focus);
    });
    final tasks = ref.watch(taskProvider);
    final scope = _scope(ref.watch(projectScopeProvider));
    // The list below filters by the account; watching it keeps it current.
    ref.watch(authProvider);
    final colors = Theme.of(context).colorScheme;
    final lists = ref.watch(taskListsProvider);
    final list = (lists.valueOrNull ?? [])
        .where((list) => list.id == widget.listId)
        .firstOrNull;
    final title = widget.listId != null
        ? list?.name ?? context.l10n.list
        : widget.isRoot
        ? context.l10n.tasks
        : context.l10n.inbox;
    final labels =
        (tasks.valueOrNull ?? []).expand((task) => task.labels).toSet().toList()
          ..sort();
    final completed = IconButton(
      tooltip: context.l10n.completedTasks,
      onPressed: () => Navigator.pushNamed(context, '/completedTasks'),
      icon: const Icon(Icons.task_alt_rounded),
    );
    // A project the user can only view, or one that's gone, gets the read-only
    // bar. While the lists are still loading, an unknown project just isn't
    // known yet, so a new one doesn't flash as read-only.
    final readOnly =
        widget.listId != null &&
        (list == null ? !lists.isLoading && lists.hasValue : !list.canEdit);
    // The project a new task goes to, when the user can add to it.
    final addTo = ref.watch(listCanEditProvider(scope.projectId))
        ? scope.projectId
        : null;
    return Scaffold(
      key: _page,
      appBar: CustomAppBar(
        title: title,
        isRoot: widget.isRoot,
        actions: [if (!widget.isRoot) completed],
      ),
      body: NestedScrollView(
        key: _nested,
        headerSliverBuilder: (context, innerScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full width: a people row that scrolls runs to the
                  // screen's edges.
                  widget.listId == null
                      ? const ProjectScopeControl(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                        )
                      : ProjectScopeControl(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          fixedProjectId: widget.listId,
                          team: _team,
                          onTeamChanged: (team) => setState(() => _team = team),
                          person: _person,
                          onPeopleChanged: (team, person) => setState(() {
                            _team = team;
                            _person = person;
                          }),
                        ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // The app bar names a project or the Inbox: no headline
                        // repeats it.
                        if (widget.isRoot)
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                context.l10n.yourTasks,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                              ),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pushNamed(context, '/lists'),
                                    child: Text(context.l10n.lists),
                                  ),
                                  completed,
                                ],
                              ),
                            ],
                          ),
                        // Elsewhere ✓ is in the app bar.
                        if (widget.isRoot || list?.inactive == true) ...[
                          if (!widget.isRoot)
                            Text(
                              context.l10n.archivedList,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          const SizedBox(height: 16),
                        ],
                        // The owner can share a project of their own from here.
                        if (list != null &&
                            (list.shared ||
                                (list.groupId == null && list.role == 'owner')))
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              icon: Icon(
                                list.shared
                                    ? Icons.group_outlined
                                    : Icons.person_add_outlined,
                              ),
                              label: Text(
                                list.shared
                                    ? context.l10n.projectMembersCount(
                                        list.people.length,
                                      )
                                    : context.l10n.shareProject,
                              ),
                              onPressed: () async {
                                final gone = await Navigator.push(
                                  context,
                                  MaterialPageRoute<bool>(
                                    builder: (_) => list.groupId == null
                                        ? ListSharingScreen(listId: list.id)
                                        : GroupScreen(groupId: list.groupId!),
                                  ),
                                );
                                // Deleted or left: this page has nothing to show.
                                if (gone == true && context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        if (widget.listId != null)
                          TextButton.icon(
                            icon: const Icon(Icons.description_outlined),
                            label: Text(context.l10n.notes),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => NotesScreen(
                                  listId: widget.listId,
                                  isRoot: false,
                                ),
                              ),
                            ),
                          ),
                        TextField(
                          controller: _search,
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          decoration: InputDecoration(
                            hintText: context.l10n.findTask,
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.isRoot)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final entry in [
                                (0, context.l10n.allTasks),
                                (3, context.l10n.inbox),
                                (1, context.l10n.today),
                                (2, context.l10n.highPriority),
                              ])
                                ChoiceChip(
                                  label: Text(entry.$2),
                                  selected: _filter == entry.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = entry.$1),
                                ),
                            ],
                          ),
                        if (labels.isNotEmpty)
                          DropdownButton<String>(
                            hint: Text(context.l10n.filterLabel),
                            value: labels.contains(_label) ? _label : null,
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(context.l10n.allLabels),
                              ),
                              for (final label in labels)
                                DropdownMenuItem(
                                  value: label,
                                  child: Text('#$label'),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _label = value == '' ? null : value,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: tasks.when(
          data: (all) {
            final filtered = _visible(
              all,
              filter: _filter,
              query: _query,
              label: _label,
            );
            if (_landingIds.isNotEmpty &&
                filtered.any((task) => _landingIds.contains(task.id))) {
              _landedIds = _landingIds;
              _landingIds = {};
              _highlight = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
            }
            if (filtered.isEmpty) {
              final filtering =
                  _query.isNotEmpty ||
                  _label != null ||
                  (widget.isRoot && _filter != 0) ||
                  (widget.listId != null && (!_team || _personShown != null));
              // Only a person's chip on: nothing was searched, so it says
              // whose tasks are missing.
              final person =
                  _query.isEmpty &&
                      _label == null &&
                      !(widget.isRoot && _filter != 0)
                  ? _personChip
                  : null;
              return ListView(
                children: [
                  EmptyState(
                    title: person != null
                        ? context.l10n.personNothingOpen(person.name)
                        : filtering
                        ? context.l10n.noMatches
                        : context.l10n.freshStart,
                    message: person != null
                        ? context.l10n.personNothingOpenHelp
                        : filtering
                        ? context.l10n.differentFilter
                        : readOnly
                        ? context.l10n.readOnlyListEmpty
                        : widget.listId != null
                        ? context.l10n.listEmpty
                        // They name the button, which can read Nueva
                        // tarea.
                        : ref.watch(opensFormProvider)
                        ? widget.isRoot
                              ? context.l10n.tasksEmptyForm
                              : context.l10n.inboxEmptyForm
                        : widget.isRoot
                        ? context.l10n.tasksEmpty
                        : context.l10n.inboxEmpty,
                    icon: Icons.check_box_outlined,
                  ),
                ],
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(taskProvider.notifier).loadTasks(),
              child: TaskList(
                tasks: filtered,
                landedIds: _landedIds,
                lit: _highlight,
                landedRow: _landedRow,
                bottomPadding: _listEnd,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EmptyState(
            title: context.l10n.loadTasksError,
            message: context.l10n.savedOnDevice,
            action: TextButton(
              onPressed: () => ref.read(taskProvider.notifier).loadTasks(),
              child: Text(
                context.l10n.tryAgain,
                style: TextStyle(color: colors.primary),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: readOnly
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: Text(context.l10n.readOnlyList),
                  subtitle: Text(context.l10n.listEditingAccessHelp),
                ),
              ),
            )
          : TaskActions(
              projectId: addTo,
              // Under a person's chip, a new task is theirs (D7).
              person: widget.listId != null && addTo == widget.listId
                  ? _personChip
                  : null,
              page: this,
            ),
    );
  }
}
