import 'package:flutter/widgets.dart';
import 'package:agenda/models/archive_diagnostic.dart';
import 'region.dart';

extension ArchiveLocale on BuildContext {
  String archiveDiagnostic(ArchiveDiagnostic issue) => switch (issue.code) {
        ArchiveCode.fileTooLarge => l10n.archiveFileTooLarge,
        ArchiveCode.unsupportedArchive => l10n.archiveUnsupportedArchive,
        ArchiveCode.invalidList => l10n.archiveInvalidList,
        ArchiveCode.duplicateLists => l10n.archiveDuplicateLists,
        ArchiveCode.invalidListStyle => l10n.archiveInvalidListStyle,
        ArchiveCode.invalidTask => l10n.archiveInvalidTask,
        ArchiveCode.duplicateTask => l10n.archiveDuplicateTask,
        ArchiveCode.invalidAttachments => l10n.archiveInvalidAttachments,
        ArchiveCode.missingList => l10n.archiveMissingList,
        ArchiveCode.invalidTaskFields => l10n.archiveInvalidTaskFields,
        ArchiveCode.unsupportedKind => l10n.archiveUnsupportedKind,
        ArchiveCode.invalidCompletion => l10n.archiveInvalidCompletion,
        ArchiveCode.twoSchedules => l10n.archiveTwoSchedules,
        ArchiveCode.twoDeadlines => l10n.archiveTwoDeadlines,
        ArchiveCode.invalidReminderDate => l10n.archiveInvalidReminderDate,
        ArchiveCode.unsupportedRepeat => l10n.archiveUnsupportedRepeat,
        ArchiveCode.weekdaysNeedWeekly => l10n.archiveWeekdaysNeedWeekly,
        ArchiveCode.repeatNeedsStart => l10n.archiveRepeatNeedsStart,
        ArchiveCode.invalidOccurrence => l10n.archiveInvalidOccurrence,
        ArchiveCode.duplicateOccurrence => l10n.archiveDuplicateOccurrence,
        ArchiveCode.invalidSkipped => l10n.archiveInvalidSkipped,
        ArchiveCode.invalidOccurrenceSchedule =>
          l10n.archiveInvalidOccurrenceSchedule,
        ArchiveCode.repeatSettingsNeedRepeat =>
          l10n.archiveRepeatSettingsNeedRepeat,
        ArchiveCode.repeatUsesCompletedDates =>
          l10n.archiveRepeatUsesCompletedDates,
        ArchiveCode.invalidChecklist => l10n.archiveInvalidChecklist,
        ArchiveCode.duplicateChecklist => l10n.archiveDuplicateChecklist,
        ArchiveCode.invalidChecklistProgress =>
          l10n.archiveInvalidChecklistProgress,
        ArchiveCode.repeatEndBeforeStart => l10n.archiveRepeatEndBeforeStart,
        ArchiveCode.occurrenceOutsideRepeat =>
          l10n.archiveOccurrenceOutsideRepeat,
        ArchiveCode.exportTooLarge => l10n.archiveExportTooLarge,
        ArchiveCode.invalidDateFormat => l10n.archiveInvalidDateFormat,
        ArchiveCode.invalidDate => l10n.archiveInvalidDate,
        ArchiveCode.missingTimezone => l10n.archiveMissingTimezone,
        ArchiveCode.invalidClock => l10n.archiveInvalidClock,
        ArchiveCode.invalidOffset => l10n.archiveInvalidOffset,
        ArchiveCode.invalidTimedDate => l10n.archiveInvalidTimedDate,
        ArchiveCode.fileUnreadable => l10n.archiveFileUnreadable,
        ArchiveCode.emptyCsv => l10n.archiveEmptyCsv,
        ArchiveCode.csvHeader => l10n.archiveCsvHeader,
        ArchiveCode.csvTaskLimit => l10n.archiveCsvTaskLimit,
        ArchiveCode.csvPriority => l10n.archiveCsvPriority,
        ArchiveCode.csvIndent => l10n.archiveCsvIndent,
        ArchiveCode.csvRecordLimit => l10n.archiveCsvRecordLimit,
        ArchiveCode.csvQuoting => l10n.archiveCsvQuoting,
        ArchiveCode.csvUnclosedQuote => l10n.archiveCsvUnclosedQuote,
        ArchiveCode.notesTooLong => l10n.archiveNotesTooLong,
        ArchiveCode.invalidFile => l10n.archiveInvalidFile,
        ArchiveCode.unknownFields => l10n.archiveUnknownFields,
        ArchiveCode.personalCopies => l10n.archivePersonalCopies,
        ArchiveCode.csvPriorities => l10n.archiveCsvPriorities,
        ArchiveCode.csvDates => l10n.archiveCsvDates,
        ArchiveCode.csvPersonalCopies => l10n.archiveCsvPersonalCopies,
        ArchiveCode.reviewSchedule => l10n.archiveReviewSchedule,
        ArchiveCode.flattenedSubtasks => l10n.archiveFlattenedSubtasks,
        ArchiveCode.inlineLabels => l10n.archiveInlineLabels,
        ArchiveCode.attachmentsOmitted =>
          l10n.archiveAttachmentsOmitted(issue.count),
        ArchiveCode.invalidCollection => l10n.archiveInvalidCollection(
            l10n.archiveField(issue.field.replaceAll(' ', '_')), issue.max),
        ArchiveCode.invalidText => l10n.archiveInvalidText(
            l10n.archiveField(issue.field.replaceAll(' ', '_')), issue.max),
        ArchiveCode.invalidInteger => l10n.archiveInvalidInteger(
            l10n.archiveField(issue.field.replaceAll(' ', '_')),
            issue.min,
            issue.max),
        ArchiveCode.invalidIdentifier => l10n.archiveInvalidIdentifier(
            l10n.archiveField(issue.field.replaceAll(' ', '_'))),
        ArchiveCode.csvExtraFields => l10n.archiveCsvExtraFields(issue.row),
        ArchiveCode.csvInvalidSection =>
          l10n.archiveCsvInvalidSection(issue.row),
        ArchiveCode.csvListDescription =>
          l10n.archiveCsvListDescription(issue.row),
        ArchiveCode.csvOrphanComment => l10n.archiveCsvOrphanComment(issue.row),
        ArchiveCode.csvUnsupportedRow =>
          l10n.archiveCsvUnsupportedRow(issue.row),
        ArchiveCode.csvFieldInNotes => l10n.archiveCsvFieldInNotes(issue.field),
      };
}
