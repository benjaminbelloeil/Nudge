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

    // MARK: - Current Language Helper

    private var lang: AppLanguage { LanguageManager.shared.language }

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

    // MARK: - Message Pools (Localized)

    private typealias Msg = (title: String, body: String)

    // swiftlint:disable function_body_length
    private func eveningMessage(ctx: Context, seed: Int) -> Msg {
        let s = ctx.streak

        if s >= 7 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("\(s) days straight 🔥", "You've built serious momentum. Don't let tonight break it."),
                ("Streak: \(s). Keep it moving.", "One nudge before bed and the streak lives another day."),
                ("\(s)-day streak 🔥", "Most people stop way before this. You haven't. Keep going."),
                ("Still going at \(s) days", "The streak isn't the point — the habit is. One nudge tonight.")
            ]
            case .spanish: [
                ("\(s) días seguidos 🔥", "Has creado un impulso serio. No dejes que esta noche lo rompa."),
                ("Racha: \(s). Sigue así.", "Un nudge antes de dormir y la racha sigue viva."),
                ("Racha de \(s) días 🔥", "La mayoría para mucho antes. Tú no. Sigue adelante."),
                ("Sigues a \(s) días", "La racha no es el punto — el hábito sí. Un nudge esta noche.")
            ]
            case .french: [
                ("\(s) jours d'affilée 🔥", "Tu as un élan sérieux. Ne laisse pas ce soir le briser."),
                ("Série : \(s). Continue.", "Un nudge avant de dormir et la série survit un jour de plus."),
                ("Série de \(s) jours 🔥", "La plupart s'arrêtent bien avant. Pas toi. Continue."),
                ("Toujours à \(s) jours", "La série n'est pas le but — l'habitude oui. Un nudge ce soir.")
            ]
            }
            return pool[seed % pool.count]
        }

        if s >= 3 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("\(s)-day streak in progress", "Keep it going. One nudge before bed."),
                ("Day \(s) on your streak 🔥", "You're building something. Don't break it tonight."),
                ("Almost at a week 💪", "You're on a roll — open Nudge and keep it up."),
                ("\(s) days in a row", "Small wins compound. One more tonight.")
            ]
            case .spanish: [
                ("Racha de \(s) días en progreso", "Sigue así. Un nudge antes de dormir."),
                ("Día \(s) de tu racha 🔥", "Estás construyendo algo. No lo rompas esta noche."),
                ("Casi una semana 💪", "Vas muy bien — abre Nudge y sigue."),
                ("\(s) días seguidos", "Las pequeñas victorias se acumulan. Una más esta noche.")
            ]
            case .french: [
                ("Série de \(s) jours en cours", "Continue. Un nudge avant de dormir."),
                ("Jour \(s) de ta série 🔥", "Tu construis quelque chose. Ne le casse pas ce soir."),
                ("Presque une semaine 💪", "Tu es lancé — ouvre Nudge et continue."),
                ("\(s) jours d'affilée", "Les petites victoires s'accumulent. Encore une ce soir.")
            ]
            }
            return pool[seed % pool.count]
        }

        if let mood = ctx.lastMood {
            switch mood {
            case .overwhelmed, .anxious:
                let pool: [Msg] = switch lang {
                case .english: [
                    ("Big day? Break it down.", "One tiny step is enough. Nudge is here when you're ready."),
                    ("Still feeling it?", "Even 2 minutes of progress counts. Open Nudge."),
                    ("You don't have to do it all", "Just the smallest possible thing. Nudge can help."),
                    ("One thing at a time", "Pick the smallest item on your mental list and tackle it.")
                ]
                case .spanish: [
                    ("¿Día difícil? Divídelo.", "Un paso pequeño es suficiente. Nudge está aquí cuando estés listo."),
                    ("¿Aún lo sientes?", "Incluso 2 minutos de progreso cuentan. Abre Nudge."),
                    ("No tienes que hacerlo todo", "Solo lo más pequeño posible. Nudge puede ayudar."),
                    ("Una cosa a la vez", "Elige lo más pequeño de tu lista mental y abórdalo.")
                ]
                case .french: [
                    ("Grosse journée ? Décompose.", "Un petit pas suffit. Nudge est là quand tu es prêt."),
                    ("Tu le ressens encore ?", "Même 2 minutes de progrès comptent. Ouvre Nudge."),
                    ("Tu n'as pas à tout faire", "Juste la plus petite chose possible. Nudge peut aider."),
                    ("Une chose à la fois", "Choisis le plus petit élément de ta liste et fonce.")
                ]
                }
                return pool[seed % pool.count]
            case .tired:
                let pool: [Msg] = switch lang {
                case .english: [
                    ("Low energy? That's okay.", "Pick 2-step mode and do the bare minimum."),
                    ("Even tired days count", "One tiny nudge before bed — that's it."),
                    ("Rest is valid. So is this.", "One small move before you close the day.")
                ]
                case .spanish: [
                    ("¿Poca energía? Está bien.", "Elige el modo de 2 pasos y haz lo mínimo."),
                    ("Los días cansados también cuentan", "Un pequeño nudge antes de dormir — eso es todo."),
                    ("Descansar es válido. Esto también.", "Un pequeño paso antes de cerrar el día.")
                ]
                case .french: [
                    ("Peu d'énergie ? C'est ok.", "Choisis le mode 2 étapes et fais le minimum."),
                    ("Même les jours fatigués comptent", "Un petit nudge avant de dormir — c'est tout."),
                    ("Se reposer est valide. Ça aussi.", "Un petit geste avant de finir la journée.")
                ]
                }
                return pool[seed % pool.count]
            case .avoidant:
                let pool: [Msg] = switch lang {
                case .english: [
                    ("Still avoiding it?", "That task isn't going anywhere. And neither is Nudge."),
                    ("The thing you're putting off…", "It'll feel better once you've started. Open Nudge."),
                    ("Avoidance is exhausting", "5 steps. That's all. Let's go."),
                    ("It's still on your mind, isn't it", "Use Nudge. Get it off your plate.")
                ]
                case .spanish: [
                    ("¿Aún lo evitas?", "Esa tarea no va a desaparecer. Y Nudge tampoco."),
                    ("Eso que estás postergando…", "Te sentirás mejor cuando empieces. Abre Nudge."),
                    ("Evitar agota", "5 pasos. Eso es todo. Vamos."),
                    ("Sigue en tu mente, ¿verdad?", "Usa Nudge. Quítatelo de encima.")
                ]
                case .french: [
                    ("Tu l'évites encore ?", "Cette tâche ne va nulle part. Et Nudge non plus."),
                    ("Ce truc que tu repousses…", "Tu te sentiras mieux une fois commencé. Ouvre Nudge."),
                    ("Éviter, c'est épuisant", "5 étapes. C'est tout. Allons-y."),
                    ("C'est encore dans ta tête, non ?", "Utilise Nudge. Libère-toi de ça.")
                ]
                }
                return pool[seed % pool.count]
            case .frustrated:
                let pool: [Msg] = switch lang {
                case .english: [
                    ("Rough day?", "Channel it. Open Nudge and cross something off."),
                    ("Frustration is fuel", "Use it. One nudge and you'll feel better."),
                    ("Turn it into output", "One focused nudge — get something done.")
                ]
                case .spanish: [
                    ("¿Día difícil?", "Canalízalo. Abre Nudge y tacha algo de la lista."),
                    ("La frustración es combustible", "Úsala. Un nudge y te sentirás mejor."),
                    ("Conviértelo en acción", "Un nudge enfocado — haz algo productivo.")
                ]
                case .french: [
                    ("Journée difficile ?", "Canalise ça. Ouvre Nudge et coche quelque chose."),
                    ("La frustration est un carburant", "Utilise-la. Un nudge et tu te sentiras mieux."),
                    ("Transforme-le en action", "Un nudge concentré — fais avancer quelque chose.")
                ]
                }
                return pool[seed % pool.count]
            case .bored:
                let pool: [Msg] = switch lang {
                case .english: [
                    ("Nothing to do? Not true.", "There's definitely something on your list. Let's tackle it."),
                    ("Bored is a great time to nudge", "Open the app. Cross something off. Feel better."),
                    ("Use the boredom 💡", "One nudge and your list gets shorter.")
                ]
                case .spanish: [
                    ("¿Nada que hacer? No es verdad.", "Seguro hay algo en tu lista. Vamos a abordarlo."),
                    ("El aburrimiento es ideal para un nudge", "Abre la app. Tacha algo. Siéntete mejor."),
                    ("Aprovecha el aburrimiento 💡", "Un nudge y tu lista se acorta.")
                ]
                case .french: [
                    ("Rien à faire ? Pas vrai.", "Il y a sûrement quelque chose sur ta liste. Allons-y."),
                    ("L'ennui, c'est le bon moment", "Ouvre l'app. Coche quelque chose. Sens-toi mieux."),
                    ("Profite de l'ennui 💡", "Un nudge et ta liste raccourcit.")
                ]
                }
                return pool[seed % pool.count]
            case .scattered:
                let pool: [Msg] = switch lang {
                case .english: [
                    ("Head all over the place?", "Nudge breaks it into one thing at a time."),
                    ("Pick one thing", "Scattered energy, focused nudge — it works."),
                    ("Can't focus?", "Let Nudge do the thinking. You just act.")
                ]
                case .spanish: [
                    ("¿Cabeza en todas partes?", "Nudge lo divide en una cosa a la vez."),
                    ("Elige una cosa", "Energía dispersa, nudge enfocado — funciona."),
                    ("¿No puedes concentrarte?", "Deja que Nudge piense. Tú solo actúa.")
                ]
                case .french: [
                    ("La tête partout ?", "Nudge découpe en une chose à la fois."),
                    ("Choisis une chose", "Énergie dispersée, nudge ciblé — ça marche."),
                    ("Tu n'arrives pas à te concentrer ?", "Laisse Nudge réfléchir. Toi, agis.")
                ]
                }
                return pool[seed % pool.count]
            default: break
            }
        }

        let pool: [Msg] = switch lang {
        case .english: [
            ("Don't end the day with this", "There's still time to make progress on something."),
            ("Evening check-in 🌙", "What's one thing you can move forward tonight?"),
            ("One nudge before bed?", "It doesn't have to be big. Just something."),
            ("The day's not over yet", "Open Nudge and finish strong."),
            ("What's sitting on your list?", "Pick one thing and tackle it before bed."),
            ("Tonight's a good time", "One small nudge before you call it a day.")
        ]
        case .spanish: [
            ("No termines el día así", "Aún hay tiempo para avanzar en algo."),
            ("Check-in nocturno 🌙", "¿Qué cosa puedes avanzar esta noche?"),
            ("¿Un nudge antes de dormir?", "No tiene que ser grande. Solo algo."),
            ("El día aún no termina", "Abre Nudge y termina con fuerza."),
            ("¿Qué hay pendiente en tu lista?", "Elige una cosa y abórdala antes de dormir."),
            ("Esta noche es buen momento", "Un pequeño nudge antes de terminar el día.")
        ]
        case .french: [
            ("Ne finis pas la journée comme ça", "Il est encore temps de progresser sur quelque chose."),
            ("Check-in du soir 🌙", "Quelle chose peux-tu faire avancer ce soir ?"),
            ("Un nudge avant de dormir ?", "Pas besoin que ce soit gros. Juste quelque chose."),
            ("La journée n'est pas finie", "Ouvre Nudge et finis en beauté."),
            ("Qu'est-ce qui traîne sur ta liste ?", "Choisis une chose et fais-la avant de dormir."),
            ("Ce soir, c'est le bon moment", "Un petit nudge avant de clore la journée.")
        ]
        }
        return pool[seed % pool.count]
    }
    // swiftlint:enable function_body_length

    private func mondayMessage(ctx: Context, seed: Int) -> Msg {
        let s = ctx.streak

        if s >= 5 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("New week, same fire 🔥", "Streak at \(s) days. Free nudges reset — keep burning."),
                ("Week starts strong 💪", "You've been consistent. Free nudges reset. Don't slow down.")
            ]
            case .spanish: [
                ("Nueva semana, mismo fuego 🔥", "Racha de \(s) días. Nudges gratis renovados — sigue ardiendo."),
                ("La semana empieza fuerte 💪", "Has sido constante. Nudges gratis renovados. No bajes el ritmo.")
            ]
            case .french: [
                ("Nouvelle semaine, même flamme 🔥", "Série de \(s) jours. Nudges gratuits réinitialisés — continue."),
                ("La semaine commence fort 💪", "Tu as été régulier. Nudges gratuits réinitialisés. Ne ralentis pas.")
            ]
            }
            return pool[seed % pool.count]
        }

        if ctx.daysSinceLastNudge >= 5 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("New week, fresh chance", "It's been a while. Free nudges reset — perfect time to come back."),
                ("Back to it 🔄", "New week, new start. Your nudges are ready.")
            ]
            case .spanish: [
                ("Nueva semana, nueva oportunidad", "Ha pasado un tiempo. Nudges gratis renovados — momento perfecto para volver."),
                ("De vuelta 🔄", "Nueva semana, nuevo comienzo. Tus nudges están listos.")
            ]
            case .french: [
                ("Nouvelle semaine, nouvelle chance", "Ça fait un moment. Nudges gratuits réinitialisés — le moment idéal pour revenir."),
                ("On s'y remet 🔄", "Nouvelle semaine, nouveau départ. Tes nudges sont prêts.")
            ]
            }
            return pool[seed % pool.count]
        }

        let pool: [Msg] = switch lang {
        case .english: [
            ("New week, fresh start ✨", "Your free nudges have reset. What are you putting off?"),
            ("Monday is the best day to start", "Free nudges reset. Pick one thing to get off your list."),
            ("New week, new chances", "What's the task you've been postponing? Today's the day."),
            ("Clean slate ✨", "Free nudges reset. Make this week count."),
            ("Week 1, Day 1 mentality", "Your nudges are ready. What's first?")
        ]
        case .spanish: [
            ("Nueva semana, nuevo inicio ✨", "Tus nudges gratis se han renovado. ¿Qué estás postergando?"),
            ("Lunes es el mejor día para empezar", "Nudges gratis renovados. Elige algo de tu lista."),
            ("Nueva semana, nuevas oportunidades", "¿Cuál es la tarea que has pospuesto? Hoy es el día."),
            ("Borrón y cuenta nueva ✨", "Nudges gratis renovados. Haz que esta semana cuente."),
            ("Mentalidad de Día 1", "Tus nudges están listos. ¿Qué va primero?")
        ]
        case .french: [
            ("Nouvelle semaine, nouveau départ ✨", "Tes nudges gratuits sont réinitialisés. Que repousses-tu ?"),
            ("Lundi est le meilleur jour pour commencer", "Nudges gratuits réinitialisés. Choisis une chose à cocher."),
            ("Nouvelle semaine, nouvelles chances", "Quelle tâche repousses-tu ? C'est le jour."),
            ("Page blanche ✨", "Nudges gratuits réinitialisés. Fais compter cette semaine."),
            ("Mentalité Jour 1", "Tes nudges sont prêts. On commence par quoi ?")
        ]
        }
        return pool[seed % pool.count]
    }

    private func wednesdayMessage(ctx: Context, seed: Int) -> Msg {
        let s = ctx.streak

        if ctx.daysSinceLastNudge >= 2 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("Haven't seen you in a bit 👀", "Wednesday's a good day to break the dry spell."),
                ("Mid-week check-in", "You haven't nudged in a couple days. Let's change that."),
                ("Come back for 2 minutes 🔄", "One nudge is all it takes to get back in the flow.")
            ]
            case .spanish: [
                ("No te hemos visto últimamente 👀", "El miércoles es buen día para romper la sequía."),
                ("Check-in de mitad de semana", "No has hecho nudge en un par de días. Cambiemos eso."),
                ("Vuelve por 2 minutos 🔄", "Un nudge es todo lo que necesitas para retomar el ritmo.")
            ]
            case .french: [
                ("On ne t'a pas vu récemment 👀", "Mercredi est un bon jour pour briser la pause."),
                ("Check-in de mi-semaine", "Tu n'as pas fait de nudge depuis quelques jours. Changeons ça."),
                ("Reviens pour 2 minutes 🔄", "Un nudge suffit pour retrouver le rythme.")
            ]
            }
            return pool[seed % pool.count]
        }

        if s >= 4 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("Halfway there — streak holding 🔥", "Keep the \(s)-day streak through the weekend."),
                ("Mid-week, mid-streak 💪", "You're at \(s) days. One nudge and the week's still perfect.")
            ]
            case .spanish: [
                ("A mitad de camino — racha intacta 🔥", "Mantén la racha de \(s) días hasta el fin de semana."),
                ("Mitad de semana, mitad de racha 💪", "Llevas \(s) días. Un nudge y la semana sigue perfecta.")
            ]
            case .french: [
                ("À mi-chemin — série intacte 🔥", "Garde la série de \(s) jours jusqu'au week-end."),
                ("Mi-semaine, mi-série 💪", "Tu es à \(s) jours. Un nudge et la semaine reste parfaite.")
            ]
            }
            return pool[seed % pool.count]
        }

        let pool: [Msg] = switch lang {
        case .english: [
            ("Halfway through the week 💪", "Got something to tackle? A nudge takes less than 2 minutes."),
            ("Wednesday energy 🚀", "The week's half done — finish the second half stronger."),
            ("Mid-week nudge 🎯", "What's the one thing that would make this week feel complete?"),
            ("Wednesday check-in", "Any tasks piling up? A quick nudge helps."),
            ("Good time for a nudge", "The week is half gone — push something across the finish line.")
        ]
        case .spanish: [
            ("Mitad de semana 💪", "¿Algo que abordar? Un nudge toma menos de 2 minutos."),
            ("Energía de miércoles 🚀", "La semana va por la mitad — termina la segunda parte más fuerte."),
            ("Nudge de mitad de semana 🎯", "¿Qué es lo que haría que esta semana se sienta completa?"),
            ("Check-in del miércoles", "¿Tareas acumulándose? Un nudge rápido ayuda."),
            ("Buen momento para un nudge", "La semana va por la mitad — empuja algo hasta la meta.")
        ]
        case .french: [
            ("Mi-semaine 💪", "Quelque chose à faire ? Un nudge prend moins de 2 minutes."),
            ("Énergie du mercredi 🚀", "La semaine est à moitié — finis la deuxième partie plus fort."),
            ("Nudge de mi-semaine 🎯", "Quelle chose rendrait cette semaine complète ?"),
            ("Check-in du mercredi", "Des tâches qui s'accumulent ? Un nudge rapide aide."),
            ("Bon moment pour un nudge", "La semaine est à moitié — pousse quelque chose jusqu'au bout.")
        ]
        }
        return pool[seed % pool.count]
    }

    private func fridayMessage(ctx: Context, seed: Int) -> Msg {
        let s = ctx.streak

        if s >= 5 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("Close the week at \(s) days 🔥", "One nudge to end the week and keep the streak alive."),
                ("Friday closer 🎯", "End the week on a \(s)-day streak. You've earned it.")
            ]
            case .spanish: [
                ("Cierra la semana a \(s) días 🔥", "Un nudge para terminar la semana y mantener la racha."),
                ("Cierre del viernes 🎯", "Termina la semana con una racha de \(s) días. Te lo has ganado.")
            ]
            case .french: [
                ("Finis la semaine à \(s) jours 🔥", "Un nudge pour clore la semaine et garder la série."),
                ("Clôture du vendredi 🎯", "Finis la semaine sur une série de \(s) jours. Tu l'as mérité.")
            ]
            }
            return pool[seed % pool.count]
        }

        if ctx.daysSinceLastNudge >= 3 {
            let pool: [Msg] = switch lang {
            case .english: [
                ("End the week on a high note", "You've been quiet this week. One nudge before the weekend."),
                ("Don't carry it into the weekend", "Clear that lingering task now. Nudge can help.")
            ]
            case .spanish: [
                ("Termina la semana en alto", "Has estado tranquilo esta semana. Un nudge antes del fin de semana."),
                ("No lo lleves al fin de semana", "Resuelve esa tarea pendiente ahora. Nudge puede ayudar.")
            ]
            case .french: [
                ("Finis la semaine en beauté", "Tu as été calme cette semaine. Un nudge avant le week-end."),
                ("Ne le traîne pas au week-end", "Règle cette tâche en suspens maintenant. Nudge peut aider.")
            ]
            }
            return pool[seed % pool.count]
        }

        let pool: [Msg] = switch lang {
        case .english: [
            ("Finish the week strong 🎯", "One more nudge before the weekend?"),
            ("Don't carry it to Monday", "Clear that lingering task now. Nudge can help."),
            ("Friday close out 🔒", "What's one thing you'd regret leaving unfinished this week?"),
            ("Weekend incoming 🎉", "Wrap up one last thing so you can actually switch off."),
            ("End the week right", "One nudge and you've earned your rest.")
        ]
        case .spanish: [
            ("Termina la semana fuerte 🎯", "¿Un nudge más antes del fin de semana?"),
            ("No lo lleves al lunes", "Resuelve esa tarea pendiente ahora. Nudge puede ayudar."),
            ("Cierre del viernes 🔒", "¿Qué es lo que lamentarías dejar sin terminar esta semana?"),
            ("Llega el fin de semana 🎉", "Cierra algo pendiente para poder desconectar de verdad."),
            ("Termina bien la semana", "Un nudge y te has ganado tu descanso.")
        ]
        case .french: [
            ("Finis la semaine en force 🎯", "Un nudge de plus avant le week-end ?"),
            ("Ne le reporte pas à lundi", "Règle cette tâche en suspens maintenant. Nudge peut aider."),
            ("Clôture du vendredi 🔒", "Qu'est-ce que tu regretterais de laisser inachevé cette semaine ?"),
            ("Week-end en vue 🎉", "Boucle un dernier truc pour pouvoir vraiment déconnecter."),
            ("Finis bien la semaine", "Un nudge et tu as mérité ton repos.")
        ]
        }
        return pool[seed % pool.count]
    }

    // MARK: - Inactivity One-Shot

    private func scheduleInactivity(daysSince: Int) {
        let d = daysSince

        let pool: [Msg] = switch lang {
        case .english: [
            ("Still there? 👀", "It's been \(d) days. Even one tiny task counts."),
            ("Missing you 🙃", "You haven't nudged in a while. Starting is the hardest part."),
            ("Come back for 2 minutes", "Pick something small. Nudge makes it easier to start."),
            ("The list isn't going away", "It's been \(d) days. Let's knock something off."),
            ("No pressure, but…", "A few days without a nudge. When you're ready — we're here.")
        ]
        case .spanish: [
            ("¿Sigues ahí? 👀", "Han pasado \(d) días. Incluso una pequeña tarea cuenta."),
            ("Te extrañamos 🙃", "No has hecho nudge en un tiempo. Empezar es lo más difícil."),
            ("Vuelve por 2 minutos", "Elige algo pequeño. Nudge facilita el comienzo."),
            ("La lista no va a desaparecer", "Han pasado \(d) días. Tachemos algo."),
            ("Sin presión, pero…", "Unos días sin nudge. Cuando estés listo — aquí estamos.")
        ]
        case .french: [
            ("Toujours là ? 👀", "Ça fait \(d) jours. Même une petite tâche compte."),
            ("Tu nous manques 🙃", "Tu n'as pas fait de nudge depuis un moment. Commencer est le plus dur."),
            ("Reviens pour 2 minutes", "Choisis quelque chose de petit. Nudge facilite le début."),
            ("La liste ne va pas disparaître", "Ça fait \(d) jours. Cochons quelque chose."),
            ("Pas de pression, mais…", "Quelques jours sans nudge. Quand tu es prêt — on est là.")
        ]
        }
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
        let s = currentStreak

        let pool: [Msg]
        if s >= 14 {
            pool = switch lang {
            case .english: [
                ("\(s)-day streak on the line 🔥", "That's a serious run. Don't let today be the day it ends."),
                ("Don't stop at \(s) days", "You're this close to a massive streak. One nudge tonight.")
            ]
            case .spanish: [
                ("Racha de \(s) días en juego 🔥", "Es una racha seria. No dejes que hoy sea el día que se rompa."),
                ("No pares a los \(s) días", "Estás muy cerca de una racha increíble. Un nudge esta noche.")
            ]
            case .french: [
                ("Série de \(s) jours en jeu 🔥", "C'est une sacrée série. Ne laisse pas aujourd'hui y mettre fin."),
                ("N'arrête pas à \(s) jours", "Tu es si près d'une série massive. Un nudge ce soir.")
            ]
            }
        } else if s >= 7 {
            pool = switch lang {
            case .english: [
                ("Week+ streak at risk ⚠️", "You're at \(s) days — one nudge to keep it alive."),
                ("\(s) days. Don't drop it.", "Still time today. Open Nudge before 8pm."),
                ("Protect the \(s)-day streak", "One more day. That's all you need.")
            ]
            case .spanish: [
                ("Racha de más de una semana en riesgo ⚠️", "Llevas \(s) días — un nudge para mantenerla."),
                ("\(s) días. No la pierdas.", "Aún hay tiempo hoy. Abre Nudge antes de las 8pm."),
                ("Protege la racha de \(s) días", "Un día más. Es todo lo que necesitas.")
            ]
            case .french: [
                ("Série de plus d'une semaine en danger ⚠️", "Tu es à \(s) jours — un nudge pour la garder."),
                ("\(s) jours. Ne lâche pas.", "Encore le temps aujourd'hui. Ouvre Nudge avant 20h."),
                ("Protège la série de \(s) jours", "Un jour de plus. C'est tout ce qu'il faut.")
            ]
            }
        } else {
            pool = switch lang {
            case .english: [
                ("Streak at risk 🔥", "\(s) days in a row. One nudge keeps it going."),
                ("Don't break it today", "You're at \(s) days. One quick nudge is all it takes."),
                ("\(s)-day streak ⚠️", "Still time to nudge today. Don't let the streak slip."),
                ("Quick reminder 🔥", "\(s)-day streak — one nudge before tonight.")
            ]
            case .spanish: [
                ("Racha en riesgo 🔥", "\(s) días seguidos. Un nudge la mantiene."),
                ("No la rompas hoy", "Llevas \(s) días. Un nudge rápido es todo lo que necesitas."),
                ("Racha de \(s) días ⚠️", "Aún hay tiempo para un nudge hoy. No dejes que se rompa."),
                ("Recordatorio rápido 🔥", "Racha de \(s) días — un nudge antes de esta noche.")
            ]
            case .french: [
                ("Série en danger 🔥", "\(s) jours d'affilée. Un nudge la maintient."),
                ("Ne la casse pas aujourd'hui", "Tu es à \(s) jours. Un nudge rapide suffit."),
                ("Série de \(s) jours ⚠️", "Encore le temps pour un nudge aujourd'hui. Ne laisse pas filer."),
                ("Rappel rapide 🔥", "Série de \(s) jours — un nudge avant ce soir.")
            ]
            }
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
