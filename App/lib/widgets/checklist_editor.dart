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
              title: Text(item == null ? 'Add a step' : 'Edit step'),
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
                    decoration: const InputDecoration(labelText: 'Step'),
                    validator: (text) => text?.trim().isNotEmpty == true
                        ? null
                        : 'Add a short step.',
                    onChanged: (text) => value = text,
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, value.trim());
                      }
                    },
                    child: const Text('Keep step'))
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
        Text('Checklist · $complete/${items.length}',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: complete / items.length,
            semanticsLabel:
                'Checklist, $complete of ${items.length} steps completed'),
        if (recurring && occurrence == null)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'These steps repeat with the task. Check them off from an occurrence’s details.')),
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
                    tooltip: 'Edit ${items[index].title}',
                    enabled: onChanged != null,
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit step')),
                          if (index > 0)
                            const PopupMenuItem(
                                value: 'up', child: Text('Move up')),
                          if (index < items.length - 1)
                            const PopupMenuItem(
                                value: 'down', child: Text('Move down')),
                          const PopupMenuItem(
                              value: 'remove', child: Text('Remove step')),
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
            label: Text(items.isEmpty ? 'Add checklist' : 'Add step')),
    ]);
  }
}
