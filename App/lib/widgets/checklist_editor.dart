import 'package:agenda/l10n/region.dart';
import 'package:flutter/material.dart';
import 'package:agenda/models/checklist_item.dart';

/// Reused by manual capture and AI review; item IDs survive edits and reordering.
class ChecklistEditor extends StatelessWidget {
  const ChecklistEditor(
      {super.key,
      required this.items,
      this.onChanged,
      this.occurrence,
      this.recurring = false});
  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>>? onChanged;
  final String? occurrence;
  final bool recurring;

  Future<void> _edit(BuildContext context, [ChecklistItem? item]) async {
    var value = item?.title ?? '';
    final form = GlobalKey<FormState>();
    final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(item == null
                  ? context.l10n.addStepDialog
                  : context.l10n.editStep),
              content: Form(
                  key: form,
                  child: TextFormField(
                    key: const ValueKey('checklist-title'),
                    initialValue: value,
                    autofocus: true,
                    maxLength: 160,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: context.l10n.step),
                    validator: (text) => text?.trim().isNotEmpty == true
                        ? null
                        : context.l10n.shortStep,
                    onChanged: (text) => value = text,
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel)),
                FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, value.trim());
                      }
                    },
                    child: Text(context.l10n.keepStep))
              ],
            ));
    if (title == null || !context.mounted) return;
    onChanged?.call(item == null
        ? [...items, ChecklistItem(title: title)]
        : items
            .map((current) => current.id == item.id
                ? current.copyWith(title: title)
                : current)
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    final complete =
        items.where((item) => item.done(occurrence: occurrence)).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (items.isNotEmpty) ...[
        Text(context.l10n.checklistCount(complete, items.length),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: complete / items.length,
            semanticsLabel:
                context.l10n.checklistSemantics(complete, items.length)),
        if (recurring && occurrence == null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.l10n.repeatingSteps)),
        for (var index = 0; index < items.length; index++)
          Row(
              key: ValueKey('checklist-${items[index].id}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                    value: items[index].done(occurrence: occurrence),
                    semanticLabel: items[index].title,
                    onChanged:
                        onChanged == null || (recurring && occurrence == null)
                            ? null
                            : (value) => onChanged!(items
                                .map((item) => item.id == items[index].id
                                    ? item.setDone(value == true,
                                        occurrence: occurrence)
                                    : item)
                                .toList())),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text(items[index].title))),
                PopupMenuButton<String>(
                    tooltip: context.l10n.editCaptureItem(items[index].title),
                    enabled: onChanged != null,
                    itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'edit',
                              child: Text(context.l10n.editStep)),
                          if (index > 0)
                            PopupMenuItem(
                                value: 'up', child: Text(context.l10n.moveUp)),
                          if (index < items.length - 1)
                            PopupMenuItem(
                                value: 'down',
                                child: Text(context.l10n.moveDown)),
                          PopupMenuItem(
                              value: 'remove',
                              child: Text(context.l10n.removeStep)),
                        ],
                    onSelected: (action) {
                      if (action == 'edit') {
                        _edit(context, items[index]);
                        return;
                      }
                      final changed = [...items];
                      final item = changed.removeAt(index);
                      if (action != 'remove') {
                        changed.insert(index + (action == 'up' ? -1 : 1), item);
                      }
                      onChanged?.call(changed);
                    }),
              ]),
      ],
      if (items.length < 50)
        TextButton.icon(
            key: const ValueKey('add-checklist-item'),
            onPressed: onChanged == null ? null : () => _edit(context),
            icon: const Icon(Icons.playlist_add_rounded),
            label: Text(items.isEmpty
                ? context.l10n.addChecklist
                : context.l10n.addStep)),
    ]);
  }
}
