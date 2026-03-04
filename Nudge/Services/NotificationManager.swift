import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - Notification Identifiers

    private static let dailyEveningID   = "nudge.daily.evening"
    private static let mondayResetID    = "nudge.weekly.monday"
    private static let wednesdayCheckID = "nudge.weekly.wednesday"
    private static let fridayWrapUpID   = "nudge.weekly.friday"
    private static let streakRiskID     = "nudge.streak.risk"

    // MARK: - Permission

    /// Returns true if notifications are authorized (or gets authorized).
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            return granted
        default:
            return false
        }
    }

    /// Returns the current authorization status without prompting.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Opens the iOS Settings app to the app's notification page.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Enable / Disable (called from Settings toggle)

    /// Called when the notifications toggle changes.
    /// Returns false if the user has denied permissions at the system level.
    @discardableResult
    func handleToggle(enabled: Bool) async -> Bool {
        if enabled {
            let granted = await requestPermission()
            if granted {
                await scheduleAll()
                return true
            } else {
                return false  // caller should revert toggle and show alert
            }
        } else {
            cancelAll()
            return true
        }
    }

    // MARK: - Schedule All

    func scheduleAll() async {
        let center = UNUserNotificationCenter.current()

        // Cancel existing scheduled notifications before re-registering
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.dailyEveningID,
            Self.mondayResetID,
            Self.wednesdayCheckID,
            Self.fridayWrapUpID
        ])

        // 1. Daily evening reminder — every day at 8:00 PM
        schedule(
            id: Self.dailyEveningID,
            title: "Don't let friction win today 🔥",
            body: "Complete a nudge and keep the momentum going.",
            hour: 20, minute: 0,
            weekday: nil,      // nil = daily
            center: center
        )

        // 2. Monday 9:00 AM — weekly free nudge reset
        schedule(
            id: Self.mondayResetID,
            title: "New week, fresh start ✨",
            body: "Your free nudges have reset. What are you putting off?",
            hour: 9, minute: 0,
            weekday: 2,        // 2 = Monday (Sunday = 1)
            center: center
        )

        // 3. Wednesday 1:00 PM — mid-week check-in
        schedule(
            id: Self.wednesdayCheckID,
            title: "Halfway through the week 💪",
            body: "Got something to tackle? A nudge takes less than 2 minutes.",
            hour: 13, minute: 0,
            weekday: 4,        // 4 = Wednesday
            center: center
        )

        // 4. Friday 5:00 PM — end-of-week nudge
        schedule(
            id: Self.fridayWrapUpID,
            title: "Finish the week strong 🎯",
            body: "One more nudge before the weekend?",
            hour: 17, minute: 0,
            weekday: 6,        // 6 = Friday
            center: center
        )
    }

    // MARK: - Streak At Risk (one-shot, called after saving a nudge)

    /// Schedules a one-time "streak at risk" notification for 7:30 PM today.
    /// Pass the current streak value; only fires if streak >= 2.
    /// Call this after every nudge is saved so the reminder is always current.
    func scheduleStreakAtRisk(currentStreak: Int) {
        // Cancel any previously scheduled streak risk for today
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.streakRiskID])

        guard currentStreak >= 2 else { return }

        // Only schedule if it's not already past 7:30 PM
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        guard hour < 19 || (hour == 19 && minute < 30) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your \(currentStreak)-day streak is at risk! 🔥"
        content.body = "You haven't done a nudge today. Keep the streak alive."
        content.sound = .default

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 19
        components.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.streakRiskID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel the streak-risk notification (call this when the user completes a nudge).
    func cancelStreakRisk() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.streakRiskID])
    }

    // MARK: - Cancel All

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Private Helpers

    private func schedule(
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        weekday: Int?,   // nil = repeat daily, Int = repeat on that weekday
        center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        if let weekday { components.weekday = weekday }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
