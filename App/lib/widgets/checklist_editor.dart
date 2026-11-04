import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:agenda/models/checklist_item.dart';

/// Reused by manual capture and AI review; item IDs survive edits and reordering.
///
/// Steps are typed in place: Enter adds one and keeps the field open for the
/// next, and leaving the field keeps what was typed.
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.items,
    this.onChanged,
    this.occurrence,
    this.recurring = false,
    this.choosing = false,
  });
  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>>? onChanged;
  final String? occurrence;
  final bool recurring;

  /// The review «Crear tarea» opens from a note (MN-22): a tick means the
  /// step goes into the task, under «Pasos que se añaden», and a step typed
  /// here starts ticked. The rows have no ⋮.
  final bool choosing;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  static const _maxSteps = 50;

  final _add = TextEditingController();
  final _addFocus = FocusNode();
  final _rename = TextEditingController();
  final _renameFocus = FocusNode();

  /// The step being renamed in place, if any.
  String? _renaming;

  @override
  void initState() {
    super.initState();
    _addFocus.addListener(_addLeft);
    _renameFocus.addListener(_renameLeft);
  }

  @override
  void dispose() {
    _addFocus.removeListener(_addLeft);
    _renameFocus.removeListener(_renameLeft);
    _add.dispose();
    _addFocus.dispose();
    _rename.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  void _addLeft() {
    if (!_addFocus.hasFocus && mounted) _addStep(next: false);
  }

  void _renameLeft() {
    if (!_renameFocus.hasFocus && mounted) _saveRename();
  }

  /// Adds the typed step. With [next], the field stays focused for another;
  /// Enter on an empty field closes the keyboard. At the step limit the text
  /// stays in the field, which says why.
  void _addStep({bool next = true}) {
    // A disabled editor never throws typed text away.
    if (widget.onChanged == null) return;
    final title = _add.text.trim();
    if (title.isEmpty || widget.items.length >= _maxSteps) {
      if (next) _addFocus.unfocus();
      return;
    }
    _add.clear();
    widget.onChanged?.call([
      ...widget.items,
      ChecklistItem(title: title, completed: widget.choosing),
    ]);
    if (next) _addFocus.requestFocus();
  }

  void _startRename(ChecklistItem item) {
    setState(() {
      _renaming = item.id;
      _rename.text = item.title;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _renaming == item.id) _renameFocus.requestFocus();
    });
  }

  void _saveRename() {
    final id = _renaming;
    if (id == null) return;
    final title = _rename.text.trim();
    setState(() => _renaming = null);
    if (title.isEmpty) return;
    widget.onChanged?.call(
      widget.items
          .map(
            (current) => current.id == id && current.title != title
                ? current.copyWith(title: title)
                : current,
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final onChanged = widget.onChanged;
    final occurrence = widget.occurrence;
    final choosing = widget.choosing;
    // Choosing, a tick is a choice, not a step done: a repeat doesn't
    // hold it back.
    final recurring = widget.recurring && !choosing;
    final complete = items
        .where((item) => item.done(occurrence: occurrence))
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty) ...[
          if (choosing)
            Text(
              context.l10n.meetingStepsToAdd,
              style: Theme.of(context).textTheme.titleSmall,
            )
          else ...[
            Text(
              context.l10n.checklistCount(complete, items.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: complete / items.length,
              semanticsLabel: context.l10n.checklistSemantics(
                complete,
                items.length,
              ),
            ),
          ],
          if (recurring && occurrence == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.l10n.repeatingSteps),
            ),
          for (var index = 0; index < items.length; index++)
            Row(
              key: ValueKey('checklist-${items[index].id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The step reads once: its checkbox, labelled with its title,
                // then its ⋮. While renaming, the field stays its own node.
                Expanded(
                  child: _mergeUnless(
                    _renaming == items[index].id,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: items[index].done(occurrence: occurrence),
                          semanticLabel: items[index].title,
                          onChanged:
                              onChanged == null ||
                                  (recurring && occurrence == null)
                              ? null
                              : (value) => onChanged(
                                  items
                                      .map(
                                        (item) => item.id == items[index].id
                                            ? item.setDone(
                                                value == true,
                                                occurrence: occurrence,
                                              )
                                            : item,
                                      )
                                      .toList(),
                                ),
                        ),
                        Expanded(
                          child: _renaming == items[index].id
                              ? TextField(
                                  key: const ValueKey('checklist-title'),
                                  controller: _rename,
                                  focusNode: _renameFocus,
                                  maxLength: 160,
                                  minLines: 1,
                                  maxLines: 3,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.done,
                                  decoration: InputDecoration(
                                    labelText: context.l10n.editStep,
                                    counterText: '',
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  // The checkbox already reads the step's title.
                                  child: ExcludeSemantics(
                                    child: Text(items[index].title),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!choosing)
                  PopupMenuButton<String>(
                    tooltip: context.l10n.editCaptureItem(items[index].title),
                    enabled: onChanged != null,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(context.l10n.editStep),
                      ),
                      if (index > 0)
                        PopupMenuItem(
                          value: 'up',
                          child: Text(context.l10n.moveUp),
                        ),
                      if (index < items.length - 1)
                        PopupMenuItem(
                          value: 'down',
                          child: Text(context.l10n.moveDown),
                        ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(context.l10n.removeStep),
                      ),
                    ],
                    onSelected: (action) {
                      if (action == 'edit') {
                        _startRename(items[index]);
                        return;
                      }
                      final changed = [...widget.items];
                      final at = changed.indexWhere(
                        (item) => item.id == items[index].id,
                      );
                      if (at < 0) return;
                      final item = changed.removeAt(at);
                      if (action != 'remove') {
                        changed.insert(at + (action == 'up' ? -1 : 1), item);
                      }
                      // A step typed but not added yet is kept, even when the
                      // last step goes and the host hides this editor.
                      final typed = _add.text.trim();
                      if (typed.isNotEmpty && changed.length < _maxSteps) {
                        _add.clear();
                        changed.add(ChecklistItem(title: typed));
                      }
                      onChanged?.call(changed);
                    },
                  ),
              ],
            ),
        ],
        // At the limit the field stays while it holds text, so none is lost.
        if (items.length < _maxSteps || _add.text.isNotEmpty)
          TextField(
            key: const ValueKey('add-checklist-item'),
            controller: _add,
            focusNode: _addFocus,
            enabled: onChanged != null,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: context.l10n.addStep,
              prefixIcon: const Icon(Icons.playlist_add_rounded),
              counterText: '',
              errorText: items.length >= _maxSteps
                  ? context.l10n.stepLimit
                  : null,
              errorMaxLines: 5,
            ),
            // At the limit, clearing the text hides the field.
            onChanged: items.length >= _maxSteps
                ? (_) => setState(() {})
                : null,
            // Enter adds the step and keeps the keyboard up for the next one.
            onEditingComplete: () {},
            onSubmitted: (_) => _addStep(),
          ),
      ],
    );
  }

  /// [child] as one TalkBack node, unless [separate].
  static Widget _mergeUnless(bool separate, Widget child) =>
      separate ? child : MergeSemantics(child: child);
}
