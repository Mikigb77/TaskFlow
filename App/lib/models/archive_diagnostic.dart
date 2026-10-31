// Stable diagnostics are localized by the UI, never embedded in imported data.
enum ArchiveCode {
  fileTooLarge,
  unsupportedArchive,
  invalidList,
  duplicateLists,
  invalidListStyle,
  invalidTask,
  duplicateTask,
  invalidAttachments,
  missingList,
  invalidTaskFields,
  unsupportedKind,
  invalidCompletion,
  twoSchedules,
  twoDeadlines,
  invalidReminderDate,
  unsupportedRepeat,
  weekdaysNeedWeekly,
  repeatNeedsStart,
  invalidOccurrence,
  duplicateOccurrence,
  invalidSkipped,
  invalidOccurrenceSchedule,
  repeatSettingsNeedRepeat,
  repeatUsesCompletedDates,
  invalidChecklist,
  duplicateChecklist,
  invalidChecklistProgress,
  repeatEndBeforeStart,
  occurrenceOutsideRepeat,
  exportTooLarge,
  invalidDateFormat,
  invalidDate,
  missingTimezone,
  invalidClock,
  invalidOffset,
  invalidTimedDate,
  fileUnreadable,
  emptyCsv,
  csvHeader,
  csvTaskLimit,
  csvPriority,
  csvIndent,
  csvRecordLimit,
  csvQuoting,
  csvUnclosedQuote,
  notesTooLong,
  invalidFile,
  unknownFields,
  personalCopies,
  csvPriorities,
  csvDates,
  csvPersonalCopies,
  reviewSchedule,
  flattenedSubtasks,
  inlineLabels,
  attachmentsOmitted,
  invalidCollection,
  invalidText,
  invalidInteger,
  invalidIdentifier,
  csvExtraFields,
  csvInvalidSection,
  csvListDescription,
  csvOrphanComment,
  csvUnsupportedRow,
  csvFieldInNotes
}

/// Also a FormatException to preserve the archive parser's error contract.
/// Warnings carry the same structured data but are never thrown.
class ArchiveDiagnostic extends FormatException {
  const ArchiveDiagnostic(this.code,
      {this.field = '',
      this.count = 0,
      this.min = 0,
      this.max = 0,
      this.row = 0});
  final ArchiveCode code;
  final String field;
  final int count;
  final int min;
  final int max;
  final int row;
  @override
  String get message => code.name;
  @override
  String toString() => 'ArchiveDiagnostic: ${code.name}';
}
