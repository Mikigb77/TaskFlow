import 'package:flutter/widgets.dart';
import 'region.dart';

extension ReminderLocale on BuildContext {
  String reminderStatus(String status) => switch (status) {
        'pending' => l10n.alertPending,
        'scheduled' => l10n.alertScheduled,
        'approximate' => l10n.alertApproximate,
        'blocked' => l10n.alertBlocked,
        'failed' => l10n.alertFailed,
        'inactive' => l10n.alertInactive,
        'elapsed' => l10n.alertElapsed,
        _ => status,
      };

  // Older installations persisted English copy; interpret only known messages.
  String reminderDiagnostic(String message) => switch (message) {
        'permission_denied' ||
        'Notifications are disabled in system settings.' =>
          l10n.reminderPermissionError,
        'schedule_failed' ||
        'The phone could not schedule this alert. Retry from Settings.' =>
          l10n.reminderScheduleError,
        'background_failed' ||
        'Background refresh could not finish. Open TaskFlow to retry.' =>
          l10n.reminderBackgroundError,
        'background_unavailable' ||
        'Automatic background refresh is unavailable. Alerts refresh when you open TaskFlow.' =>
          l10n.reminderBackgroundUnavailable,
        'action_failed' ||
        'A notification action could not finish. Open the task to retry.' =>
          l10n.reminderActionError,
        'setup_failed' ||
        'Notification setup could not finish. Retry from Settings.' =>
          l10n.reminderSetupError,
        'account_refresh_failed' ||
        'Account reminders could not refresh. Open notification settings to retry.' =>
          l10n.reminderAccountError,
        'refresh_failed' ||
        'Reminders could not refresh. Your tasks are saved; retry from notification settings.' =>
          l10n.reminderRefreshError,
        'Notification setup could not finish. Retry again or check system settings.' =>
          l10n.reminderSetupError,
        _ => message,
      };
}
