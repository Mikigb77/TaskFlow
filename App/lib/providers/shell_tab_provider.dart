import 'package:flutter_riverpod/legacy.dart';

/// Counts tab switches in the main shell, so a delayed question can tell the
/// person moved on.
final shellTabSwitchesProvider = StateProvider<int>((ref) => 0);
