import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agenda/l10n/region.dart';
import 'package:agenda/providers/auth_provider.dart';
import 'package:agenda/providers/subscription_provider.dart';
import 'package:agenda/widgets/app_components.dart';
import 'package:agenda/widgets/custom_app_bar.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.billingResult(result.name))),
    );
  }

  Future<void> _openStore(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https' ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Store could not be opened');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.billingStoreOpenError)),
        );
      }
    }
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
    final storeUrl = state.customerInfo?.managementURL;
    return Scaffold(
      appBar: CustomAppBar(title: l10n.taskflowPro),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          AppSurface(
            color: colors.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: colors.onPrimaryContainer,
                  size: 32,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.taskflowPro,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.complimentary
                      ? l10n.billingComplimentary
                      : l10n.billingIntro,
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
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
              ],
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
          if (!state.hasPro && state.monthly != null) ...[
            Text(
              l10n.billingMonthlyPrice(state.monthly!.storeProduct.priceString),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.billingRenewalHelp),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('subscription-paywall'),
              onPressed: state.canPurchase
                  ? () => _run(() => controller.presentPaywall(locale))
                  : null,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(l10n.billingViewPlans),
            ),
            // Direct checkout is handy for Test Store diagnostics. Production uses the
            // dashboard paywall, where benefits, trial conditions and legal links live.
            if (config.isTestStore)
              TextButton(
                key: const ValueKey('subscription-purchase'),
                onPressed: state.canPurchase
                    ? () => _run(controller.purchaseMonthly)
                    : null,
                child: Text(l10n.billingTestMonthly),
              ),
          ],
          if (!state.complimentary)
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('subscription-manage'),
              onPressed: state.ready && !state.busy
                  ? () => _run(() => controller.presentCustomerCenter(locale))
                  : null,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(l10n.billingManage),
            ),
          ],
          if (storeUrl != null)
            TextButton(
              onPressed: state.busy ? null : () => _openStore(storeUrl),
              child: Text(l10n.billingOpenStore),
            ),
          if (config.issue == null || state.complimentary)
            TextButton.icon(
              onPressed: state.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.billingRefresh),
            ),
          const SizedBox(height: 16),
          if (!state.complimentary)
            Text(
              l10n.billingRestoreHelp,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
