import Foundation
import UserNotifications

/// Local notifications at each tracked work's next release date. No server involved.
enum ReminderScheduler {
    static let enabledKey = "remindersEnabled"
    private static let identifierPrefix = "release-"
    /// iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 60

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces every pending release reminder with one per upcoming release.
    static func reschedule(works: [Work], enabled: Bool, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        )
        guard enabled else { return }

        let requests = works
            .filter { $0.status.isTracked }
            .compactMap { work -> (date: Date, request: UNNotificationRequest)? in
                guard let date = work.nextReleaseAt, date > now else { return nil }
                let content = UNMutableNotificationContent()
                content.title = work.title
                content.body = "\(work.kind.newReleaseText(mode: work.mode)) · tu en es à \(work.positionText)"
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: identifierPrefix + work.id.uuidString,
                    content: content,
                    trigger: trigger
                )
                return (date, request)
            }
            .sorted { $0.date < $1.date }
            .prefix(maxPending)

        for item in requests {
            try? await center.add(item.request)
        }
    }
}
