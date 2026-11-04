import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/calendar_focus_provider.dart';
import 'package:agenda/services/api_client.dart';
import 'package:agenda/services/revenuecat_service.dart';
import 'package:agenda/widgets/meeting_banners.dart';

final billingConfigurationProvider = Provider(
  (ref) => BillingConfiguration.environment(),
);
final revenueCatGatewayProvider = Provider<RevenueCatGateway>(
  (ref) => NativeRevenueCatGateway(),
);
final subscriptionProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
      final controller = SubscriptionController(
        ref.read(revenueCatGatewayProvider),
        ref.read(billingConfigurationProvider),
        refreshAccount: () => ref.read(authProvider.notifier).refreshAccount(),
      );
      ref.listen(authProvider, (previous, next) {
        if (next.loading) {
          controller.suspend();
          return;
        }
        final api = ref.read(apiClientProvider);
        final account = next.account;
        unawaited(
          controller.setIdentity(
            account == null ? 'guest' : '${api.baseUrl}/users/${account.id}',
            () async {
              if (account == null) return null;
              // Upgrade sessions cached before billing IDs existed, without blocking login/offline tasks.
              final id =
                  account.billingId ?? (await api.refreshAccount()).billingId;
              if (id == null || id.isEmpty) {
                throw StateError('The server has no billing identity.');
              }
              return id;
            },
            complimentary: account?.complimentaryPro == true,
          ),
        );
      }, fireImmediately: true);
      return controller;
    });

/// UI access only. Paid backend resources require server-side verification too.
final hasProProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).hasPro,
);

/// The mic: with Pro, or while free dictations are left this month. Read
/// from the saved account, so it never waits on the network; a saved count
/// from before the reset counts as the whole new month. A server that sends
/// no count leaves the mic to Pro. Never while a meeting records: the
/// meeting holds the mic, and every entry types (UX-2704).
final voiceAvailableProvider = Provider<bool>(
  (ref) =>
      !ref.watch(meetingHoldsMicProvider) &&
      (ref.watch(hasProProvider) ||
          (ref.watch(freeVoiceLeftProvider) ?? 0) > 0),
);

/// A meeting records on this phone for the signed-in account.
final meetingHoldsMicProvider = Provider<bool>(
  (ref) => ref.watch(meetingsProvider.select((m) => m.recording != null)),
);

/// Free dictations left now, for an account without Pro; null with Pro or
/// when the server sent no count.
final freeVoiceLeftProvider = Provider<int?>((ref) {
  if (ref.watch(hasProProvider)) return null;
  final free = ref.watch(authProvider.select((s) => s.account?.freeVoice));
  return free?.leftAt(ref.watch(calendarClockProvider)());
});

/// An account without Pro has used this month's free dictations: Añadir
/// tarea becomes Nueva tarea, which opens the form, and its first tap that
/// month says why. False while billing is still finding out whether the
/// account has Pro, and when the server sent no count.
final freeVoiceUsedUpProvider = Provider<bool>(
  (ref) =>
      !ref.watch(billingLoadingProvider) &&
      ref.watch(freeVoiceLeftProvider) == 0,
);

/// An account without Pro, once billing has answered: words it types never
/// become tasks on the phone. It creates tasks with the form, and the
/// capture sheet's keyboard opens the form (DECISIONS.md, 2026-10-18
/// later). Dictations, and `Guardar como tarea` after one, stay. False while
/// billing is still finding out: then the sheet types as before.
final typesInFormProvider = Provider<bool>(
  (ref) => !ref.watch(billingLoadingProvider) && !ref.watch(hasProProvider),
);

/// Añadir tarea opens the form at once, as Nueva tarea: an account without
/// Pro and without the mic (no free dictation left this month, or a server
/// that sends no count).
final opensFormProvider = Provider<bool>(
  (ref) => ref.watch(typesInFormProvider) && !ref.watch(voiceAvailableProvider),
);

/// When free dictations come back: the saved date, else the next calendar
/// month (UTC), as the server counts them.
final freeVoiceResetsProvider = Provider<DateTime>((ref) {
  final now = ref.watch(calendarClockProvider)();
  final resets = ref.watch(
    authProvider.select((s) => s.account?.freeVoice?.resetsAt),
  );
  return resets != null && now.isBefore(resets)
      ? resets
      : FreeVoice.nextReset(now);
});

/// Whether billing is still finding out if the account has Pro.
final billingLoadingProvider = Provider<bool>(
  (ref) => ref.watch(subscriptionProvider).loading,
);

enum BillingResult {
  active,
  restored,
  noPurchases,
  awaitingEntitlement,
  updated,
  cancelled,
  pending,
  failed,
  busy,
  accountChanged,
}

class SubscriptionState {
  const SubscriptionState({
    this.customerInfo,
    this.offering,
    this.ready = false,
    this.busy = false,
    this.complimentary = false,
    this.issue,
  });
  final CustomerInfo? customerInfo;
  final Offering? offering;
  final bool ready;
  final bool busy;
  final bool complimentary;
  final BillingIssue? issue;
  EntitlementInfo? get pro => customerInfo?.entitlements.active[proEntitlement];
  bool get hasPro =>
      ready &&
      (complimentary ||
          (pro?.isActive == true &&
              pro?.verification != VerificationResult.failed &&
              customerInfo?.entitlements.verification !=
                  VerificationResult.failed));
  Package? get monthly {
    final package = offering?.monthly ?? offering?.getPackage('monthly');
    // Never label an annual/lifetime product as monthly, even if misconfigured in the dashboard.
    return package?.storeProduct.subscriptionPeriod == 'P1M' ? package : null;
  }

  bool get canPurchase => ready && !busy && customerInfo != null && !hasPro;

  /// Billing hasn't said yet whether this account has Pro. [hasPro] reads
  /// false meanwhile, so capture waits instead of guessing.
  bool get loading => !ready && issue == null;
  SubscriptionState copyWith({
    CustomerInfo? customerInfo,
    Offering? offering,
    bool? ready,
    bool? busy,
    bool? complimentary,
    BillingIssue? issue,
    bool clearOffering = false,
  }) => SubscriptionState(
    customerInfo: customerInfo ?? this.customerInfo,
    offering: clearOffering ? null : offering ?? this.offering,
    ready: ready ?? this.ready,
    busy: busy ?? this.busy,
    complimentary: complimentary ?? this.complimentary,
    issue: issue,
  );
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(
    this.gateway,
    this.configuration, {
    this.refreshAccount,
  }) : super(SubscriptionState(issue: configuration.issue));
  final RevenueCatGateway gateway;
  final BillingConfiguration configuration;
  final Future<void> Function()? refreshAccount;
  Future<void> _queue = Future.value();
  String? _identityKey;
  Future<String?> Function()? _resolveIdentity;
  int _generation = 0;
  bool _configured = false;
  bool _listening = false;
  bool _complimentary = false;
  bool _refreshingAccount = false;
  void _listener(CustomerInfo _) {
    // Callbacks carry an original ID which can be an alias, not the current ID.
    // Read afresh inside our identity queue instead of trusting a late callback's payload.
    if (mounted && state.ready && !state.busy) unawaited(refresh());
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final future = _queue.then((_) => operation());
    _queue = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  bool _current(int generation) => mounted && _generation == generation;

  void suspend() {
    _generation++;
    _identityKey = null;
    state = SubscriptionState(busy: true, issue: configuration.issue);
  }

  Future<void> setIdentity(
    String key,
    Future<String?> Function() resolve, {
    bool complimentary = false,
  }) {
    if (_identityKey == key && _complimentary == complimentary) return _queue;
    _identityKey = key;
    _complimentary = complimentary;
    _resolveIdentity = resolve;
    final generation = ++_generation;
    // Clear another account's entitlement synchronously, even while a native modal is open.
    state = SubscriptionState(
      busy: configuration.issue == null,
      issue: configuration.issue,
    );
    if (complimentary) {
      state = const SubscriptionState(ready: true, complimentary: true);
      return Future.value();
    }
    if (configuration.issue != null) return Future.value();
    return _serialized(() async {
      if (!_current(generation)) return;
      String? id;
      try {
        id = await resolve();
      } catch (_) {
        if (_current(generation)) {
          state = const SubscriptionState(
            issue: BillingIssue.accountUnavailable,
          );
        }
        return;
      }
      if (!_current(generation)) return;
      try {
        if (!_configured) {
          await gateway.configure(configuration, id);
          _configured = true;
        }
        if (!_current(generation)) return;
        final info = await gateway.identify(id);
        if (!_current(generation)) return;
        state = SubscriptionState(customerInfo: info, ready: true, busy: true);
        if (!_listening) {
          gateway.addListener(_listener);
          _listening = true;
        }
        await _loadOfferings(generation);
      } catch (error) {
        if (_current(generation)) {
          state = SubscriptionState(issue: billingIssue(error));
        }
      } finally {
        if (_current(generation)) {
          state = state.copyWith(busy: false, issue: state.issue);
        }
      }
    });
  }

  Future<void> _loadOfferings(int generation) async {
    try {
      final current = (await gateway.offerings()).current;
      if (!_current(generation)) return;
      state = state.copyWith(offering: current, clearOffering: current == null);
      if (state.monthly == null) {
        state = state.copyWith(issue: BillingIssue.configuration);
      }
    } catch (error) {
      if (_current(generation)) {
        state = state.copyWith(clearOffering: true, issue: billingIssue(error));
      }
    }
  }

  Future<void> refresh() async {
    if (!mounted || state.busy || _refreshingAccount) return;
    if (refreshAccount != null) {
      _refreshingAccount = true;
      try {
        await refreshAccount!();
      } finally {
        _refreshingAccount = false;
      }
    }
    if (!mounted ||
        state.busy ||
        state.complimentary ||
        configuration.issue != null) {
      return;
    }
    if (!state.ready) {
      final key = _identityKey;
      final resolve = _resolveIdentity;
      if (key != null && resolve != null) {
        _identityKey = null;
        await setIdentity(key, resolve);
      }
      return;
    }
    final generation = _generation;
    state = state.copyWith(busy: true);
    await _serialized(() async {
      if (!_current(generation)) return;
      try {
        final info = await gateway.customerInfo();
        if (!_current(generation)) return;
        state = state.copyWith(customerInfo: info);
        await _loadOfferings(generation);
      } catch (error) {
        // Preserve SDK-verified cached access for this identity on temporary failures.
        if (_current(generation)) {
          state = state.copyWith(issue: billingIssue(error));
        }
      } finally {
        if (_current(generation)) {
          state = state.copyWith(busy: false, issue: state.issue);
        }
      }
    });
  }

  Future<BillingResult> _perform(
    Future<BillingResult> Function(int generation) action,
  ) {
    if (!state.ready || state.busy) return Future.value(BillingResult.busy);
    final generation = _generation;
    state = state.copyWith(busy: true);
    return _serialized(() async {
      if (!_current(generation)) return BillingResult.accountChanged;
      try {
        final result = await action(generation);
        return _current(generation) ? result : BillingResult.accountChanged;
      } catch (error) {
        if (!_current(generation)) return BillingResult.accountChanged;
        switch (purchaseErrorCode(error)) {
          case PurchasesErrorCode.purchaseCancelledError:
            return BillingResult.cancelled;
          case PurchasesErrorCode.paymentPendingError:
            return BillingResult.pending;
          case PurchasesErrorCode.operationAlreadyInProgressError:
            return BillingResult.busy;
          default:
            state = state.copyWith(issue: billingIssue(error));
            return BillingResult.failed;
        }
      } finally {
        if (_current(generation)) {
          state = state.copyWith(busy: false, issue: state.issue);
        }
      }
    });
  }

  Future<BillingResult> purchaseMonthly() {
    if (state.hasPro) return Future.value(BillingResult.active);
    final package = state.monthly;
    if (package == null) return Future.value(BillingResult.failed);
    return _perform((generation) async {
      final info = await gateway.purchase(package);
      if (_current(generation)) state = state.copyWith(customerInfo: info);
      return state.hasPro
          ? BillingResult.active
          : BillingResult.awaitingEntitlement;
    });
  }

  Future<BillingResult> restorePurchases() => _perform((generation) async {
    final info = await gateway.restore();
    if (_current(generation)) state = state.copyWith(customerInfo: info);
    return state.hasPro ? BillingResult.restored : BillingResult.noPurchases;
  });

  Future<BillingResult> presentPaywall(String locale) {
    if (state.hasPro) return Future.value(BillingResult.active);
    final offering = state.offering;
    if (offering == null || state.monthly == null) {
      return Future.value(BillingResult.failed);
    }
    return _perform((generation) async {
      await gateway.setLocale(locale);
      if (!_current(generation)) return BillingResult.accountChanged;
      final result = await gateway.paywall(offering);
      if (!_current(generation)) return BillingResult.accountChanged;
      // A successful dialog alone never grants access. Entitlements are authoritative.
      final info = await gateway.customerInfo();
      if (_current(generation)) state = state.copyWith(customerInfo: info);
      if (state.hasPro) return BillingResult.active;
      return switch (result) {
        PaywallResult.cancelled => BillingResult.cancelled,
        PaywallResult.error => BillingResult.failed,
        PaywallResult.restored => BillingResult.noPurchases,
        _ => BillingResult.awaitingEntitlement,
      };
    });
  }

  Future<BillingResult> presentCustomerCenter(String locale) =>
      _perform((generation) async {
        await gateway.setLocale(locale);
        if (!_current(generation)) return BillingResult.accountChanged;
        await gateway.customerCenter();
        if (!_current(generation)) return BillingResult.accountChanged;
        final info = await gateway.customerInfo();
        if (_current(generation)) state = state.copyWith(customerInfo: info);
        return BillingResult.updated;
      });

  @override
  void dispose() {
    _generation++;
    if (_listening) gateway.removeListener(_listener);
    super.dispose();
  }
}
