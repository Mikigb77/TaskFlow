import 'package:flutter/material.dart';
import 'package:agenda/l10n/region.dart';

/// A search field that ends with a ✕ while it holds text: one tap empties
/// it and tells [onChanged] '', so the whole list shows again. While empty
/// it has no ✕ and looks as a plain field. Every search in the app is one,
/// so they can't drift.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    required this.decoration,
    required this.onChanged,
  });

  /// Kept by the screen when it clears or reads the words itself; else the
  /// field keeps its own.
  final TextEditingController? controller;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _own;
  late bool _empty = _controller.text.isEmpty;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_changed);
      _controller.addListener(_changed);
      _empty = _controller.text.isEmpty;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  /// The ✕ comes and goes with the words, however they change: typed, or
  /// cleared by the screen.
  void _changed() {
    final empty = _controller.text.isEmpty;
    if (empty != _empty && mounted) setState(() => _empty = empty);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    decoration: widget.decoration.copyWith(
      suffixIcon: _empty
          ? null
          : IconButton(
              tooltip: context.l10n.clearSearch,
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
            ),
    ),
  );
}
