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
    private static let inactivityID     = "nudge.inactivity"

    // MARK: - Context (built from live entry data)

    private struct Context {
        let streak: Int
        let lastMood: Mood?
        let daysSinceLastNudge: Int
    }

    private func buildContext(from entries: [NudgeEntry]) -> Context {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let lastDate = entries.sorted { $0.createdAt > $1.createdAt }.first?.createdAt
        let daysSince: Int
        if let last = lastDate {
            daysSince = max(0, calendar.dateComponents([.day],
                from: calendar.startOfDay(for: last), to: today).day ?? 0)
        } else {
            daysSince = 999
        }

        let lastMood = entries.sorted { $0.createdAt > $1.createdAt }.first?.mood

        let hasEntryToday = entries.contains { calendar.isDate($0.createdAt, inSameDayAs: today) }
        let startDate = hasEntryToday
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        let hasEntryOnStart = entries.contains { calendar.isDate($0.createdAt, inSameDayAs: startDate) }
        var streak = 0
        if hasEntryOnStart {
            var checkDate = startDate
            while true {
                let has = entries.contains { calendar.isDate($0.createdAt, inSameDayAs: checkDate) }
                if has {
                    streak += 1
                    guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = prev
                } else { break }
            }
        }
        return Context(streak: streak, lastMood: lastMood, daysSinceLastNudge: daysSince)
    }

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

    @discardableResult
    func handleToggle(enabled: Bool) async -> Bool {
        if enabled {
            let granted = await requestPermission()
            if granted { await scheduleAll(); return true }
            return false
        } else {
            cancelAll()
            return true
        }
    }

    // MARK: - Schedule All

    func scheduleAll() async {
        let entries = PersistenceManager.shared.entries
        let ctx = buildContext(from: entries)
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: [
            Self.dailyEveningID, Self.mondayResetID,
            Self.wednesdayCheckID, Self.fridayWrapUpID, Self.inactivityID
        ])

        // Seed changes each day so recurring slots show a different message every time they fire
        let seed = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1

        let ev = eveningMessage(ctx: ctx, seed: seed)
        schedule(id: Self.dailyEveningID, title: ev.title, body: ev.body,
                 hour: 20, minute: 0, weekday: nil, center: center)

        let mo = mondayMessage(ctx: ctx, seed: seed)
        schedule(id: Self.mondayResetID, title: mo.title, body: mo.body,
                 hour: 9, minute: 0, weekday: 2, center: center)

        let we = wednesdayMessage(ctx: ctx, seed: seed)
        schedule(id: Self.wednesdayCheckID, title: we.title, body: we.body,
                 hour: 13, minute: 0, weekday: 4, center: center)

        let fr = fridayMessage(ctx: ctx, seed: seed)
        schedule(id: Self.fridayWrapUpID, title: fr.title, body: fr.body,
                 hour: 17, minute: 0, weekday: 6, center: center)

        // Inactivity one-shot — fires tomorrow at 11am if inactive 3+ days
        if ctx.daysSinceLastNudge >= 3 {
            scheduleInactivity(daysSince: ctx.daysSinceLastNudge)
        }
    }

    // MARK: - Message Pools

    private typealias Msg = (title: String, body: String)

    private func eveningMessage(ctx: Context, seed: Int) -> Msg {
        if ctx.streak >= 7 {
            let pool: [Msg] = [
                ("\(ctx.streak) days straight 🔥", "You've built serious momentum. Don't let tonight break it."),
                ("Streak: \(ctx.streak). Keep it moving.", "One nudge before bed and the streak lives another day."),
                ("\(ctx.streak)-day streak 🔥", "Most people stop way before this. You haven't. Keep going."),
                ("Still going at \(ctx.streak) days", "The streak isn't the point — the habit is. One nudge tonight.")
            ]
            return pool[seed % pool.count]
        }
        if ctx.streak >= 3 {
            let pool: [Msg] = [
                ("\(ctx.streak)-day streak in progress", "Keep it going. One nudge before bed."),
                ("Day \(ctx.streak) on your streak 🔥", "You're building something. Don't break it tonight."),
                ("Almost at a week 💪", "You're on a roll — open Nudge and keep it up."),
                ("\(ctx.streak) days in a row", "Small wins compound. One more tonight.")
            ]
            return pool[seed % pool.count]
        }
        if let mood = ctx.lastMood {
            switch mood {
            case .overwhelmed, .anxious:
                let pool: [Msg] = [
                    ("Big day? Break it down.", "One tiny step is enough. Nudge is here when you're ready."),
                    ("Still feeling it?", "Even 2 minutes of progress counts. Open Nudge."),
                    ("You don't have to do it all", "Just the smallest possible thing. Nudge can help."),
                    ("One thing at a time", "Pick the smallest item on your mental list and tackle it.")
                ]
                return pool[seed % pool.count]
            case .tired:
                let pool: [Msg] = [
                    ("Low energy? That's okay.", "Pick 2-step mode and do the bare minimum."),
                    ("Even tired days count", "One tiny nudge before bed — that's it."),
                    ("Rest is valid. So is this.", "One small move before you close the day.")
                ]
                return pool[seed % pool.count]
            case .avoidant:
                let pool: [Msg] = [
                    ("Still avoiding it?", "That task isn't going anywhere. And neither is Nudge."),
                    ("The thing you're putting off…", "It'll feel better once you've started. Open Nudge."),
                    ("Avoidance is exhausting", "5 steps. That's all. Let's go."),
                    ("It's still on your mind, isn't it", "Use Nudge. Get it off your plate.")
                ]
                return pool[seed % pool.count]
            case .frustrated:
                let pool: [Msg] = [
                    ("Rough day?", "Channel it. Open Nudge and cross something off."),
                    ("Frustration is fuel", "Use it. One nudge and you'll feel better."),
                    ("Turn it into output", "One focused nudge — get something done.")
                ]
                return pool[seed % pool.count]
            case .bored:
                let pool: [Msg] = [
                    ("Nothing to do? Not true.", "There's definitely something on your list. Let's tackle it."),
                    ("Bored is a great time to nudge", "Open the app. Cross something off. Feel better."),
                    ("Use the boredom 💡", "One nudge and your list gets shorter.")
                ]
                return pool[seed % pool.count]
            case .scattered:
                let pool: [Msg] = [
                    ("Head all over the place?", "Nudge breaks it into one thing at a time."),
                    ("Pick one thing", "Scattered energy, focused nudge — it works."),
                    ("Can't focus?", "Let Nudge do the thinking. You just act.")
                ]
                return pool[seed % pool.count]
            default: break
            }
        }
        let pool: [Msg] = [
            ("Don't end the day with this", "There's still time to make progress on something."),
            ("Evening check-in 🌙", "What's one thing you can move forward tonight?"),
            ("One nudge before bed?", "It doesn't have to be big. Just something."),
            ("The day's not over yet", "Open Nudge and finish strong."),
            ("What's sitting on your list?", "Pick one thing and tackle it before bed."),
            ("Tonight's a good time", "One small nudge before you call it a day.")
        ]
        return pool[seed % pool.count]
    }

    private func mondayMessage(ctx: Context, seed: Int) -> Msg {
        if ctx.streak >= 5 {
            let pool: [Msg] = [
                ("New week, same fire 🔥", "Streak at \(ctx.streak) days. Free nudges reset — keep burning."),
                ("Week starts strong 💪", "You've been consistent. Free nudges reset. Don't slow down.")
            ]
            return pool[seed % pool.count]
        }
        if ctx.daysSinceLastNudge >= 5 {
            let pool: [Msg] = [
                ("New week, fresh chance", "It's been a while. Free nudges reset — perfect time to come back."),
                ("Back to it 🔄", "New week, new start. Your nudges are ready.")
            ]
            return pool[seed % pool.count]
        }
        let pool: [Msg] = [
            ("New week, fresh start ✨", "Your free nudges have reset. What are you putting off?"),
            ("Monday is the best day to start", "Free nudges reset. Pick one thing to get off your list."),
            ("New week, new chances", "What's the task you've been postponing? Today's the day."),
            ("Clean slate ✨", "Free nudges reset. Make this week count."),
            ("Week 1, Day 1 mentality", "Your nudges are ready. What's first?")
        ]
        return pool[seed % pool.count]
    }

    private func wednesdayMessage(ctx: Context, seed: Int) -> Msg {
        if ctx.daysSinceLastNudge >= 2 {
            let pool: [Msg] = [
                ("Haven't seen you in a bit 👀", "Wednesday's a good day to break the dry spell."),
                ("Mid-week check-in", "You haven't nudged in a couple days. Let's change that."),
                ("Come back for 2 minutes 🔄", "One nudge is all it takes to get back in the flow.")
            ]
            return pool[seed % pool.count]
        }
        if ctx.streak >= 4 {
            let pool: [Msg] = [
                ("Halfway there — streak holding 🔥", "Keep the \(ctx.streak)-day streak through the weekend."),
                ("Mid-week, mid-streak 💪", "You're at \(ctx.streak) days. One nudge and the week's still perfect.")
            ]
            return pool[seed % pool.count]
        }
        let pool: [Msg] = [
            ("Halfway through the week 💪", "Got something to tackle? A nudge takes less than 2 minutes."),
            ("Wednesday energy 🚀", "The week's half done — finish the second half stronger."),
            ("Mid-week nudge 🎯", "What's the one thing that would make this week feel complete?"),
            ("Wednesday check-in", "Any tasks piling up? A quick nudge helps."),
            ("Good time for a nudge", "The week is half gone — push something across the finish line.")
        ]
        return pool[seed % pool.count]
    }

    private func fridayMessage(ctx: Context, seed: Int) -> Msg {
        if ctx.streak >= 5 {
            let pool: [Msg] = [
                ("Close the week at \(ctx.streak) days 🔥", "One nudge to end the week and keep the streak alive."),
                ("Friday closer 🎯", "End the week on a \(ctx.streak)-day streak. You've earned it.")
            ]
            return pool[seed % pool.count]
        }
        if ctx.daysSinceLastNudge >= 3 {
            let pool: [Msg] = [
                ("End the week on a high note", "You've been quiet this week. One nudge before the weekend."),
                ("Don't carry it into the weekend", "Clear that lingering task now. Nudge can help.")
            ]
            return pool[seed % pool.count]
        }
        let pool: [Msg] = [
            ("Finish the week strong 🎯", "One more nudge before the weekend?"),
            ("Don't carry it to Monday", "Clear that lingering task now. Nudge can help."),
            ("Friday close out 🔒", "What's one thing you'd regret leaving unfinished this week?"),
            ("Weekend incoming 🎉", "Wrap up one last thing so you can actually switch off."),
            ("End the week right", "One nudge and you've earned your rest.")
        ]
        return pool[seed % pool.count]
    }

    // MARK: - Inactivity One-Shot

    private func scheduleInactivity(daysSince: Int) {
        let pool: [Msg] = [
            ("Still there? 👀", "It's been \(daysSince) days. Even one tiny task counts."),
            ("Missing you 🙃", "You haven't nudged in a while. Starting is the hardest part."),
            ("Come back for 2 minutes", "Pick something small. Nudge makes it easier to start."),
            ("The list isn't going away", "It's been \(daysSince) days. Let's knock something off."),
            ("No pressure, but…", "A few days without a nudge. When you're ready — we're here.")
        ]
        let pick = pool[daysSince % pool.count]

        let content = UNMutableNotificationContent()
        content.title = pick.title
        content.body = pick.body
        content.sound = .default

        guard let fireDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 11
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.inactivityID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Streak At Risk — contextual message pools

    func scheduleStreakAtRisk(currentStreak: Int) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.streakRiskID])

        guard currentStreak >= 2 else { return }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        guard hour < 19 || (hour == 19 && minute < 30) else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

        let pool: [(title: String, body: String)]
        if currentStreak >= 14 {
            pool = [
                ("\(currentStreak)-day streak on the line 🔥", "That's a serious run. Don't let today be the day it ends."),
                ("Don't stop at \(currentStreak) days", "You're this close to a massive streak. One nudge tonight.")
            ]
        } else if currentStreak >= 7 {
            pool = [
                ("Week+ streak at risk ⚠️", "You're at \(currentStreak) days — one nudge to keep it alive."),
                ("\(currentStreak) days. Don't drop it.", "Still time today. Open Nudge before 8pm."),
                ("Protect the \(currentStreak)-day streak", "One more day. That's all you need.")
            ]
        } else {
            pool = [
                ("Streak at risk 🔥", "\(currentStreak) days in a row. One nudge keeps it going."),
                ("Don't break it today", "You're at \(currentStreak) days. One quick nudge is all it takes."),
                ("\(currentStreak)-day streak ⚠️", "Still time to nudge today. Don't let the streak slip."),
                ("Quick reminder 🔥", "\(currentStreak)-day streak — one nudge before tonight.")
            ]
        }

        let pick = pool[currentStreak % pool.count]
        content.title = pick.title
        content.body = pick.body

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 19
        components.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.streakRiskID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

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
