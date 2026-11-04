import 'dart:async';
import 'dart:math' as math;
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/services/text_search.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/screens/groups_screen.dart';
import 'package:agenda/screens/list_sharing_screen.dart';
import 'package:agenda/providers/project_scope_provider.dart';
import 'package:agenda/providers/shell_tab_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/completed_tasks_screen.dart';
import 'package:agenda/widgets/project_scope_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/providers/task_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/search_clear.dart';
import 'package:agenda/widgets/custom_app_bar.dart';
import 'package:agenda/widgets/task_list.dart';
import 'package:agenda/widgets/task_actions.dart';
import 'package:agenda/models/task.dart';
import 'package:agenda/models/task_list_info.dart';
import 'package:agenda/providers/task_lists_provider.dart';
import 'package:agenda/screens/notes_screen.dart';
import 'package:agenda/screens/task_lists_screen.dart';

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
  // Rows seen open on this page, by task occurrence. One ticked here keeps
  // its place, struck through, until the person leaves the tab or the page,
  // or changes the search or a filter: Calendar's rule.
  final _openHere = <String>{};
  // The project's DELETE is on its way: a spinner stands in for its ⋮.
  bool _deletingProject = false;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    if (person == null || widget.listId == null) return;
    if (person == ref.read(authProvider).account?.id) {
      // `Para mí` only where its chip shows: on a shared project.
      _team = !(ref.read(taskListsProvider).value ?? []).any(
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
    final project = (ref.read(taskListsProvider).value ?? [])
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
    final projects = ref.read(taskListsProvider).value ?? [];
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
                  (filter == 3 && task.undated) ||
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

  static final _sideButton = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 8),
  );

  static String _row(Task task) => '${task.id}:${task.occurrenceId}';

  /// The rows this page shows: [open], and the tasks ticked here since the
  /// list last changed, struck through where they were. A repeating task's
  /// next occurrence waits until its ticked one goes.
  List<Task> _rows(List<Task> all, List<Task> open) {
    final ticked = <Task>[];
    for (final task in all) {
      if (task.isNote) continue;
      if (task.isRecurring) {
        for (final key in task.completedDates) {
          if (!_openHere.contains('${task.id}:$key')) continue;
          final done = task.completedOccurrence(key);
          if (done != null) ticked.add(done);
        }
      } else if (task.isCompleted && _openHere.contains(_row(task))) {
        ticked.add(task);
      }
    }
    final waiting = {for (final task in ticked) task.id};
    final shown = open
        .where(
          (task) =>
              !waiting.contains(task.id) || _openHere.contains(_row(task)),
        )
        .toList();
    _openHere.addAll(shown.map(_row));
    // In the tasks' own order, so a ticked row keeps its place among rows
    // the list's sort ranks the same, as undated ones.
    final at = {for (final (i, task) in all.indexed) task.id: i};
    final rows = [...shown, ...ticked].indexed.toList()
      ..sort((a, b) {
        final order = at[a.$2.id]!.compareTo(at[b.$2.id]!);
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, task) in rows) task];
  }

  /// Changes the search or a filter: a row ticked before then goes.
  void _refilter(VoidCallback change) => setState(() {
    change();
    _openHere.clear();
  });

  /// What this page lists: its own project and `Para mí` choice, or else
  /// the app-wide ones.
  ProjectScope _scope(ProjectScope global) => widget.listId == null
      ? global
      : ProjectScope(projectId: widget.listId, team: _team);

  /// Capture, or the form, opened here saved [focus]'s tasks. If the search
  /// or a filter would hide them, clear it, so they are on screen every
  /// time: on a project page, `Para mí` and a person too, when need be;
  /// elsewhere the app-wide `Para mí`, then the project filter. A page that
  /// can't list them even so (Sin fecha, for a task given a day; a project,
  /// for a task put in another one) sends them to Calendar, as the Día view
  /// does.
  void _land(CalendarFocus focus) {
    final all = ref.read(taskProvider).value ?? [];
    bool lists(List<Task> tasks) =>
        tasks.any((task) => focus.taskIds.contains(task.id));
    final global = ref.read(projectScopeProvider);
    final wider = widget.listId != null
        ? global
        : scopeShowing(
            all.where((task) => focus.taskIds.contains(task.id)),
            global,
            ref.read(authProvider).account?.id,
            ref.read(taskListsProvider).value ?? [],
          );
    // The first of these that lists them: as it is, then each wider step.
    final step =
        [
          (false, false, false),
          (true, false, false),
          if (widget.listId != null) (true, true, false),
          if (!identical(wider, global)) ...[
            (false, false, true),
            (true, false, true),
          ],
        ].where((step) {
          final (clear, everyone, widen) = step;
          return lists(
            _visible(
              all,
              filter: clear && widget.isRoot ? 0 : _filter,
              query: clear ? '' : _query,
              label: clear ? null : _label,
              everyone: everyone,
              global: widen ? wider : global,
            ),
          );
        }).firstOrNull;
    if (step == null) {
      _landOnCalendar(focus);
      return;
    }
    final (clear, everyone, widen) = step;
    setState(() {
      if (clear) {
        _search.clear();
        _query = '';
        _label = null;
        if (widget.isRoot) _filter = 0;
        _openHere.clear();
      }
      if (everyone) {
        _team = true;
        _person = null;
        _openHere.clear();
      }
      _landingIds = focus.taskIds;
      _landedIds = {};
      _highlight = false;
      _highlightTimer?.cancel();
    });
    if (widen) {
      ref.read(projectScopeProvider.notifier).state = wider;
      ref.read(scopeWideningProvider.notifier).state = ScopeWidening(
        focus,
        global,
        wider,
      );
    }
  }

  /// Shows [focus]'s tasks on Calendar instead, lit on their day (or its
  /// no-date row), as the Día view does.
  void _landOnCalendar(CalendarFocus focus) {
    final calendarFocus = ref.read(calendarFocusProvider.notifier);
    final widening = ref.read(scopeWideningProvider.notifier);
    Navigator.of(context).popUntil((route) => route.isFirst);
    // Once this focus has reached every listener.
    scheduleMicrotask(() {
      final there = CalendarFocus(
        focus.day,
        focus.taskIds,
        showCalendar: true,
        undated: focus.undated,
      );
      calendarFocus.state = there;
      // A filter Calendar widened for them: the save's Deshacer, which knows
      // only [focus], narrows it again.
      final widened = widening.state;
      if (widened != null && identical(widened.landing, there)) {
        widening.state = ScopeWidening(focus, widened.before, widened.after);
      }
    });
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

  /// Whether this page has its own button for [list]'s members, or for
  /// sharing it: the owner can share a project of their own from here.
  bool _sharesHere(TaskListInfo list) =>
      list.shared || (list.groupId == null && list.role == 'owner');

  /// Deletes the project after asking, then closes its page and says so on
  /// the one below, as leaving it does.
  Future<void> _deleteProject(TaskListInfo list) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.l10n;
    final tasks = ref.read(taskProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final gone = await deleteProject(
      context,
      ref,
      list,
      onSending: () => setState(() => _deletingProject = true),
    );
    if (!mounted) return;
    if (!gone) {
      setState(() => _deletingProject = false);
      return;
    }
    // True tells Proyectos to drop the row before the sync catches up.
    navigator.pop(true);
    showFeedback(messenger, strings.projectDeleted);
    // The sync takes the project's tasks off this phone behind it.
    unawaited(
      tasks.loadTasks().then((_) => container.invalidate(taskListsProvider)),
    );
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
    // Another tab, or another project chosen: a row ticked before goes.
    ref.listen<int>(shellTabSwitchesProvider, (_, _) {
      setState(_openHere.clear);
    });
    ref.listen<ProjectScope>(projectScopeProvider, (_, _) {
      setState(_openHere.clear);
    });
    // The page is covered by another screen: the person has left it.
    if (!TickerMode.valuesOf(context).enabled) _openHere.clear();
    final tasks = ref.watch(taskProvider);
    final scope = _scope(ref.watch(projectScopeProvider));
    // The list below filters by the account; watching it keeps it current.
    ref.watch(authProvider);
    final colors = Theme.of(context).colorScheme;
    final lists = ref.watch(taskListsProvider);
    final list = (lists.value ?? [])
        .where((list) => list.id == widget.listId)
        .firstOrNull;
    final title = widget.listId != null
        ? list?.name ?? context.l10n.list
        : widget.isRoot
        ? context.l10n.tasks
        : context.l10n.inbox;
    final labels =
        (tasks.value ?? []).expand((task) => task.labels).toSet().toList()
          ..sort();
    final all = tasks.value;
    final rows = all == null
        ? null
        : _rows(
            all,
            _visible(all, filter: _filter, query: _query, label: _label),
          );
    final filtering =
        _query.isNotEmpty ||
        _label != null ||
        (widget.isRoot && _filter != 0) ||
        (widget.listId != null && (!_team || _personShown != null));
    // Nothing to search or filter yet: the empty state says what to do. A
    // row ticked moments ago still counts, so the header doesn't jump.
    final quiet =
        (widget.isRoot || widget.listId != null) &&
        !filtering &&
        rows?.isEmpty != false;
    // «Prioridad alta» only while it would find something, or is chosen.
    final urgent =
        _filter == 2 ||
        (all != null &&
            [
              ..._visible(all, filter: 0, query: '', label: null),
              ...?rows,
            ].any((task) => task.priority == 3));
    // A project page's ✓ lists what was done there, for the person shown.
    final completed = IconButton(
      tooltip: context.l10n.completedTasks,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CompletedTasksScreen(
            listId: widget.listId,
            team: _team,
            person: _personShown,
          ),
        ),
      ),
      icon: const Icon(Icons.task_alt_rounded),
    );
    // A project the user can only view, or one that's gone, gets the read-only
    // bar. While the lists are still loading, an unknown project just isn't
    // known yet, so a new one doesn't flash as read-only.
    final readOnly =
        widget.listId != null &&
        (list == null ? !lists.isLoading && lists.hasValue : !list.canEdit);
    // An archived project, or one archived with its group, takes no new
    // tasks: they'd show nowhere else and never remind.
    final archived = widget.listId != null && list?.inactive == true;
    // Restoring the project alone can't bring back one archived with its
    // group; only who can manage it gets the button and the hint to use it.
    final canRestore =
        archived && list!.archived && !list.groupArchived && list.canManage;
    // The project a new task goes to, when the user can add to it.
    final addTo = ref.watch(listCanEditProvider(scope.projectId))
        ? scope.projectId
        : null;
    // The page's ⋮: its own button opens the members or sharing, and
    // pinning only reorders Proyectos. With nothing left, there's no ⋮.
    final menu = list == null
        ? const <PopupMenuEntry<String>>[]
        : projectMenuItems(
            context,
            ref,
            list,
            people: !_sharesHere(list),
            pin: false,
          );
    return Scaffold(
      key: _page,
      appBar: CustomAppBar(
        title: title,
        isRoot: widget.isRoot,
        actions: [
          if (widget.listId != null) completed,
          // 8 dp apart, so a tap meant for ✓ doesn't open the menu.
          if (menu.isNotEmpty) const SizedBox(width: 8),
          if (list != null && menu.isNotEmpty)
            _deletingProject
                ? const ProjectDeleting()
                : PopupMenuButton<String>(
                    tooltip: context.l10n.manageItem(list.name),
                    itemBuilder: (_) => menu,
                    onSelected: (action) async {
                      final gone = await runProjectAction(
                        context,
                        ref,
                        list,
                        action,
                        delete: () => _deleteProject(list),
                      );
                      if (gone && context.mounted) Navigator.pop(context);
                    },
                  ),
        ],
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
                          onTeamChanged: (team) =>
                              _refilter(() => _team = team),
                          person: _person,
                          onPeopleChanged: (team, person) => _refilter(() {
                            _team = team;
                            _person = person;
                          }),
                        ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 8 dp: a project page's buttons keep their place
                        // under the people row when they wrap at large text.
                        const SizedBox(height: 8),
                        // The app bar names a project or the Inbox: no headline
                        // repeats it.
                        // Narrower than a TextButton's own 12 dp sides, so both
                        // fit beside the headline at 1× in Spanish.
                        if (widget.isRoot)
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                context.l10n.yourTasks,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton(
                                    style: _sideButton,
                                    onPressed: () =>
                                        Navigator.pushNamed(context, '/lists'),
                                    child: Text(context.l10n.lists),
                                  ),
                                  TextButton(
                                    style: _sideButton,
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      '/completedTasks',
                                    ),
                                    child: Text(context.l10n.completedButton),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        if (widget.isRoot) const SizedBox(height: 8),
                        // Side by side, apart, wrapping only when they must.
                        if (widget.listId != null) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // The owner can share a project of their own
                              // from here.
                              if (list != null && _sharesHere(list))
                                TextButton.icon(
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
                                            : GroupScreen(
                                                groupId: list.groupId!,
                                              ),
                                      ),
                                    );
                                    // Deleted or left: this page has nothing
                                    // to show.
                                    if (gone == true && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
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
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (!quiet) ...[
                          SearchField(
                            controller: _search,
                            onChanged: (value) =>
                                _refilter(() => _query = value.trim()),
                            decoration: InputDecoration(
                              hintText: context.l10n.findTask,
                              prefixIcon: const Icon(Icons.search_rounded),
                              isDense: true,
                              // 48 dp at 1×: a line above the tasks, not a form.
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                          ),
                          SizedBox(height: widget.isRoot ? 8 : 12),
                        ],
                      ],
                    ),
                  ),
                  // One row, full width: when the chips don't fit, it
                  // scrolls sideways and the next chip shows cut at the
                  // screen's edge. None chosen lists everything.
                  if (widget.isRoot && !quiet)
                    SingleChildScrollView(
                      key: const ValueKey('task-filters'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final (filter, name) in [
                            (3, context.l10n.inbox),
                            (1, context.l10n.today),
                            if (urgent) (2, context.l10n.highPriority),
                          ])
                            FilterChip(
                              label: Text(name),
                              selected: _filter == filter,
                              onSelected: (on) =>
                                  _refilter(() => _filter = on ? filter : 0),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      widget.isRoot ? 12 : 20,
                    ),
                    child: labels.isEmpty
                        ? null
                        : DropdownButton<String>(
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
                            onChanged: (value) => _refilter(
                              () => _label = value == '' ? null : value,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: tasks.when(
          data: (_) {
            final filtered = rows ?? const <Task>[];
            if (_landingIds.isNotEmpty &&
                filtered.any((task) => _landingIds.contains(task.id))) {
              _landedIds = _landingIds;
              _landingIds = {};
              _highlight = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
            }
            if (filtered.isEmpty) {
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
                        : readOnly || archived
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
                project: widget.listId,
                // Under Sin fecha, as a page or a filter, rows don't each
                // say so.
                showUndated: _filter != 3,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => EmptyState(
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
      bottomNavigationBar: archived
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(
                        canRestore
                            ? context.l10n.archivedListAddHelp
                            : context.l10n.archivedListNoAdd,
                      ),
                    ),
                    if (canRestore)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.unarchive_outlined),
                            label: Text(context.l10n.restoreList),
                            onPressed: () => restoreProject(context, ref, list),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : readOnly
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
