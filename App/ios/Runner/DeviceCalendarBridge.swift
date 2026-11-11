import EventKit
import Flutter
import UIKit

/// The iOS side of `taskflow/device_calendars`, on EventKit: the same calls
/// and answers as Android's DeviceCalendarBridge.kt. It reads the calendars
/// the person allows, and changes only the events TaskFlow added for its
/// tasks, after they turn on «TaskFlow in your calendar».
final class DeviceCalendarBridge {
  private let channel: FlutterMethodChannel
  private var store = EKEventStore()
  private let worker = DispatchQueue(label: "taskflow.device-calendars")
  private var observer: NSObjectProtocol?
  private static let day: TimeInterval = 86_400

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "taskflow/device_calendars", binaryMessenger: messenger)
    observer = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: nil, queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod("changed", arguments: nil)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status", "writeStatus":
      result(status())
    case "requestPermission", "requestWritePermission":
      request(result)
    case "settings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "calendars":
      read(result) { self.calendars() }
    case "events":
      guard let start = (arguments["start"] as? NSNumber)?.doubleValue,
        let end = (arguments["end"] as? NSNumber)?.doubleValue,
        let ids = arguments["calendars"] as? [String],
        end > start, end - start <= 3 * Self.day * 1000, !ids.isEmpty, ids.count <= 50
      else {
        return result(FlutterError(code: "calendar_range", message: "Choose up to 50 calendars and a bounded date range.", details: nil))
      }
      read(result) { self.events(start: start / 1000, end: end / 1000, ids: Set(ids)) }
    case "write":
      guard let writes = arguments["writes"] as? [[String: Any]], writes.count <= 100 else {
        return result(FlutterError(code: "calendar_write", message: "Send up to 100 changes at once.", details: nil))
      }
      read(result) { writes.map { self.apply($0) } }
    case "open":
      guard granted() else {
        return result(FlutterError(code: "calendar_permission", message: "Calendar access is unavailable.", details: nil))
      }
      // iOS opens Calendar on the event's day; it has no link to one event.
      let start = ((arguments["start"] as? NSNumber)?.doubleValue ?? 0) / 1000
      let reference = Date(timeIntervalSince1970: start).timeIntervalSinceReferenceDate
      guard let url = URL(string: "calshow:\(Int(reference))") else {
        return result(FlutterError(code: "calendar_open", message: "No calendar app could open this event.", details: nil))
      }
      UIApplication.shared.open(url) { opened in
        result(opened ? nil : FlutterError(code: "calendar_open", message: "No calendar app could open this event.", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func granted() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) { return status == .fullAccess }
    return status == .authorized
  }

  private func status() -> String {
    if granted() { return "granted" }
    switch EKEventStore.authorizationStatus(for: .event) {
    case .notDetermined: return "denied"
    default: return "blocked"
    }
  }

  private func request(_ result: @escaping FlutterResult) {
    if granted() { return result("granted") }
    let done: (Bool, Error?) -> Void = { _, _ in
      DispatchQueue.main.async {
        // A store made before access was given doesn't see the calendars.
        self.store = EKEventStore()
        result(self.status())
      }
    }
    if #available(iOS 17.0, *) {
      store.requestFullAccessToEvents(completion: done)
    } else {
      store.requestAccess(to: .event, completion: done)
    }
  }

  private func read(_ result: @escaping FlutterResult, _ operation: @escaping () throws -> Any) {
    guard granted() else {
      return result(FlutterError(code: "calendar_permission", message: "Calendar access is unavailable.", details: nil))
    }
    worker.async {
      do {
        let value = try operation()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "calendar_read", message: "Calendars could not be read. Try refreshing.", details: nil))
        }
      }
    }
  }

  private func calendars() -> [String: Any] {
    let main = store.defaultCalendarForNewEvents?.calendarIdentifier
    let all = store.calendars(for: .event)
      .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    let items: [[String: Any]] = all.prefix(200).map { calendar -> [String: Any] in
      let source = calendar.source
      let type: String
      switch calendar.type {
      case .birthday: type = "birthdays"
      case .subscription: type = "subscription"
      default: type = ""
      }
      return [
        "id": calendar.calendarIdentifier,
        "name": calendar.title,
        "account": source?.sourceType == .local ? "" : (source?.title ?? ""),
        "accountType": Self.sourceType(source?.sourceType),
        "sourceId": calendar.calendarIdentifier,
        "color": Self.argb(calendar.cgColor),
        "writable": calendar.allowsContentModifications,
        "primary": calendar.calendarIdentifier == main,
        "type": type,
      ]
    }
    return ["items": items, "truncated": all.count > 200]
  }

  private func events(start: TimeInterval, end: TimeInterval, ids: Set<String>) -> [String: Any] {
    let calendars = store.calendars(for: .event).filter { ids.contains($0.calendarIdentifier) }
    if calendars.isEmpty { return ["items": [], "truncated": false] }
    // The extra day either side keeps all-day events of far time zones.
    let predicate = store.predicateForEvents(
      withStart: Date(timeIntervalSince1970: start - Self.day),
      end: Date(timeIntervalSince1970: end + Self.day), calendars: calendars)
    let found = store.events(matching: predicate)
      .filter { $0.status != .canceled }
      .sorted { $0.startDate < $1.startDate }
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let items: [[String: Any]] = found.prefix(1000).map { event -> [String: Any] in
      var from = event.startDate!, until = event.endDate!
      if event.isAllDay {
        // Android's all-day dates are UTC midnights with an exclusive end.
        let local = Calendar.current
        let first = local.dateComponents([.year, .month, .day], from: from)
        let last = local.dateComponents([.year, .month, .day], from: until)
        from = utc.date(from: first) ?? from
        until = utc.date(byAdding: .day, value: 1, to: utc.date(from: last) ?? until) ?? until
      }
      return [
        "id": event.eventIdentifier ?? "",
        "calendarId": event.calendar.calendarIdentifier,
        "title": String((event.title ?? "").prefix(500)),
        "location": String((event.location ?? "").prefix(1000)),
        "start": Int(from.timeIntervalSince1970 * 1000),
        "end": Int(until.timeIntervalSince1970 * 1000),
        "allDay": event.isAllDay,
        "timezone": event.timeZone?.identifier ?? "",
        "uid": event.calendarItemExternalIdentifier ?? "",
      ]
    }
    return ["items": items, "truncated": found.count > 1000]
  }

  /// An insert answers the new event's id ("" when it failed); others "ok" or "gone".
  private func apply(_ write: [String: Any]) -> String {
    let op = write["op"] as? String ?? ""
    guard let calendarId = write["calendar"] as? String,
      let calendar = store.calendar(withIdentifier: calendarId)
    else { return op == "insert" ? "" : "gone" }
    let id = write["event"] as? String ?? ""
    let existing = id.isEmpty ? nil : store.event(withIdentifier: id)
    do {
      switch op {
      case "delete":
        if let existing, existing.calendar.calendarIdentifier == calendarId {
          try store.remove(existing, span: .thisEvent, commit: true)
        }
        return "ok"
      case "update":
        guard let existing, existing.calendar.calendarIdentifier == calendarId else { return "gone" }
        fill(existing, write)
        try store.save(existing, span: .thisEvent, commit: true)
        return "ok"
      case "insert":
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        fill(event, write)
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier ?? ""
      default:
        return ""
      }
    } catch {
      return op == "insert" ? "" : "gone"
    }
  }

  private func fill(_ event: EKEvent, _ write: [String: Any]) {
    let allDay = write["allDay"] as? Bool ?? false
    let start = Date(timeIntervalSince1970: ((write["start"] as? NSNumber)?.doubleValue ?? 0) / 1000)
    let end = Date(timeIntervalSince1970: ((write["end"] as? NSNumber)?.doubleValue ?? 0) / 1000)
    event.title = String((write["title"] as? String ?? "").prefix(500))
    event.isAllDay = allDay
    if allDay {
      // The day is sent as UTC midnights; EventKit keeps all-day events on
      // the phone's own days.
      var utc = Calendar(identifier: .gregorian)
      utc.timeZone = TimeZone(identifier: "UTC")!
      let first = utc.dateComponents([.year, .month, .day], from: start)
      let local = Calendar.current
      let day = local.date(from: first) ?? start
      event.timeZone = nil
      event.startDate = day
      event.endDate = local.date(byAdding: .day, value: 1, to: day)?.addingTimeInterval(-1) ?? day
    } else {
      event.timeZone = TimeZone.current
      event.startDate = start
      event.endDate = end
    }
  }

  private static func sourceType(_ type: EKSourceType?) -> String {
    switch type {
    case .local: return "local"
    case .exchange: return "exchange"
    case .calDAV: return "calDAV"
    case .mobileMe: return "mobileMe"
    case .subscribed: return "subscribed"
    case .birthdays: return "birthdays"
    default: return ""
    }
  }

  private static func argb(_ color: CGColor?) -> Int {
    guard let color, let parts = color.converted(
      to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components,
      parts.count >= 3
    else { return 0 }
    let channel = { (value: CGFloat) in Int((max(0, min(1, value)) * 255).rounded()) }
    let alpha = parts.count >= 4 ? channel(parts[3]) : 255
    let value = (alpha << 24) | (channel(parts[0]) << 16) | (channel(parts[1]) << 8) | channel(parts[2])
    // Dart reads a signed 32-bit int, as Android sends it.
    return Int(Int32(truncatingIfNeeded: value))
  }
}
