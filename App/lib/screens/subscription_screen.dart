import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/screens/tasks_with_files_screen.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

/// What led to the Pro screen, when a Pro choice was tapped: the screen
/// says first what Pro gives there.
enum ProReason { reminderPlans }

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key, this.reason});

  /// Pushed with this as the `/subscription` route's arguments.
  final ProReason? reason;
  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static const _megabyte = 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(subscriptionProvider.notifier).refresh();
    });
  }

  Future<void> _run(Future<BillingResult> Function() action) async {
    final result = await action();
    if (!mounted || result == BillingResult.cancelled) return;
    showFeedback(
      ScaffoldMessenger.of(context),
      context.l10n.billingResult(result.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);
    final controller = ref.read(subscriptionProvider.notifier);
    final config = ref.watch(billingConfigurationProvider);
    final account = ref.watch(authProvider).account;
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final expiration = DateTime.tryParse(state.pro?.expirationDate ?? '');
    // Without Pro: the free dictations and file space, from the saved account.
    final free =
        account != null &&
        !account.complimentaryPro &&
        !state.complimentary &&
        !state.hasPro &&
        !state.loading;
    final freeVoice = free ? account.freeVoice : null;
    final freeVoiceLeft = ref.watch(freeVoiceLeftProvider);
    final storage = free ? account.storage : null;
    final voiceLine = freeVoice != null && freeVoiceLeft != null
        ? l10n.freeVoiceStatus(
            freeVoiceLeft,
            freeVoice.limit,
            context.shortDate(ref.watch(freeVoiceResetsProvider).toLocal()),
          )
        : null;
    final storageLine = storage != null && storage.limitBytes > 0
        ? l10n.storageUsage(
            (storage.usedBytes / _megabyte).round(),
            (storage.limitBytes / _megabyte).round(),
          )
        : null;
    // Without Pro, «Ver suscripción» stays in view, as the task form's button.
    final offer = !state.hasPro && state.monthly != null;
    final restore = !state.complimentary && !state.hasPro;
    final reason = widget.reason == ProReason.reminderPlans;
    // The height of a benefit's first line, for its check icon: the body text
    // the Scaffold's Material gives its Text.
    final bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    final benefitLineHeight =
        MediaQuery.textScalerOf(context).scale(bodyStyle.fontSize ?? 14) *
        (bodyStyle.height ?? 1.5);
    return Scaffold(
      appBar: CustomAppBar(title: l10n.taskflowPro),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          AppSurface(
            color: colors.primaryContainer,
            // With a reason, each line its own node, so the reason reads first
            // as a heading.
            child: Semantics(
              container: reason,
              explicitChildNodes: reason,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Opened from a Pro choice: what Pro gives there, first, with
                  // an example; then your plan, then what Pro gives.
                  if (reason) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.billingReasonReminderPlans,
                        key: const ValueKey('subscription-reason'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colors.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.billingReasonReminderPlansExample,
                      key: const ValueKey('subscription-reason-example'),
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Your plan first: the status, then its renewal or dictations left.
                  Text(
                    l10n.billingStatus(
                      state.hasPro
                          ? 'active'
                          : state.customerInfo == null
                          ? 'unknown'
                          : 'inactive',
                    ),
                    key: const ValueKey('subscription-status'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  if (state.hasPro && expiration != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.billingUntil(
                        state.pro!.willRenew ? 'renews' : 'expires',
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(expiration.toLocal()),
                      ),
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                  ],
                  if (voiceLine != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      voiceLine,
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Then what Pro gives, one line each; the app bar already
                  // says «TaskFlow Pro», and a reason's heading names its own.
                  if (state.complimentary)
                    Text(
                      l10n.billingComplimentary,
                      style: TextStyle(color: colors.onPrimaryContainer),
                    )
                  else
                    for (final (index, benefit) in [
                      l10n.proBenefitDictation,
                      l10n.proBenefitTyping,
                      if (!reason) l10n.proBenefitReminders,
                    ].indexed)
                      Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 20 dp at every text size, level with its first
                            // line.
                            SizedBox(
                              height: benefitLineHeight,
                              child: Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                benefit,
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  // Without Pro, the file space after what Pro gives: at 2×
                  // in Catalan, the first benefit stays above the pinned
                  // «Ver suscripción».
                  if (storageLine != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      storageLine,
                      style: TextStyle(color: colors.onPrimaryContainer),
                    ),
                    // A full space: which tasks use it, to make room.
                    if (storage!.usedBytes >= storage.limitBytes)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onPrimaryContainer,
                        ),
                        onPressed: () => TasksWithFilesScreen.open(context),
                        child: Text(l10n.storageSeeTasks),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (config.isTestStore && !state.complimentary) ...[
            const SizedBox(height: 20),
            AppSurface(child: Text(l10n.billingTestMode)),
          ],
          if (account == null) ...[
            const SizedBox(height: 20),
            Text(l10n.billingGuestHelp),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: state.busy
                    ? null
                    : () => Navigator.pushNamed(context, '/account'),
                child: Text(l10n.billingSignIn),
              ),
            ),
          ],
          if (state.busy) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(semanticsLabel: l10n.billingWorking),
          ],
          if (state.issue != null) ...[
            const SizedBox(height: 20),
            Text(
              l10n.billingError(state.issue!.name),
              key: const ValueKey('subscription-error'),
              style: TextStyle(color: colors.error),
            ),
          ],
          const SizedBox(height: 24),
          if (offer) ...[
            Text(
              l10n.billingMonthlyPrice(state.monthly!.storeProduct.priceString),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.billingRenewalHelp),
            const SizedBox(height: 20),
            // Direct checkout is handy for Test Store diagnostics. Production uses the
            // dashboard paywall, where benefits, trial conditions and legal links live.
            if (config.isTestStore) ...[
              TextButton(
                key: const ValueKey('subscription-purchase'),
                onPressed: state.canPurchase
                    ? () => _run(controller.purchaseMonthly)
                    : null,
                child: Text(l10n.billingTestMonthly),
              ),
              const SizedBox(height: 8),
            ],
          ],
          // With Pro, «Gestionar suscripción» stands alone.
          if (restore)
            OutlinedButton.icon(
              key: const ValueKey('subscription-restore'),
              onPressed: state.ready && !state.busy
                  ? () => _run(controller.restorePurchases)
                  : null,
              icon: const Icon(Icons.restore),
              label: Text(l10n.billingRestore),
            ),
          if (state.customerInfo?.allPurchasedProductIdentifiers.isNotEmpty ==
              true) ...[
            if (restore) const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('subscription-manage'),
              onPressed: state.ready && !state.busy
                  ? () => _run(() => controller.presentCustomerCenter(locale))
                  : null,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(l10n.billingManage),
            ),
          ],
          if (restore) ...[
            const SizedBox(height: 16),
            Text(
              l10n.billingRestoreHelp,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
      bottomNavigationBar: offer
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: FilledButton.icon(
                  key: const ValueKey('subscription-paywall'),
                  onPressed: state.canPurchase
                      ? () => _run(() => controller.presentPaywall(locale))
                      : null,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    l10n.billingViewPlans,
                    textAlign: TextAlign.center,
                    textWidthBasis: TextWidthBasis.longestLine,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
