import SwiftUI
import Combine

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case spanish = "es"
    case french  = "fr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .french:  "Français"
        }
    }

    var flag: String {
        switch self {
        case .english: "🇺🇸"
        case .spanish: "🇪🇸"
        case .french:  "🇫🇷"
        }
    }
}

// MARK: - Language Manager

@MainActor
final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? Locale.current.language.languageCode?.identifier ?? "en"
        language = AppLanguage(rawValue: saved) ?? .english
    }

    /// Subscript shorthand: `lang["key"]`
    subscript(_ key: String) -> String {
        strings[language]?[key] ?? strings[.english]?[key] ?? key
    }

    // MARK: - Locale Helpers

    var locale: Locale {
        switch language {
        case .english: Locale(identifier: "en_US")
        case .spanish: Locale(identifier: "es_ES")
        case .french:  Locale(identifier: "fr_FR")
        }
    }

    /// Very-short weekday symbols (Sunday-first) for the current locale.
    var weekdaySymbols: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.veryShortWeekdaySymbols
    }

    // MARK: - Translation Table

    // swiftlint:disable line_length
    private let strings: [AppLanguage: [String: String]] = [

        // ─────────────────────────────────────────────────────────────────
        .english: [
            // Dashboard
            "dashboard.greeting.morning":       "GOOD MORNING",
            "dashboard.greeting.afternoon":     "GOOD AFTERNOON",
            "dashboard.greeting.evening":       "GOOD EVENING",
            "dashboard.new_nudge":              "New Nudge",
            "dashboard.new_nudge_subtitle":     "Start your next task",
            "dashboard.recent":                 "RECENT",
            "dashboard.view_all":               "View all",
            "dashboard.calendar":               "CALENDAR",
            "dashboard.no_nudges_title":        "No nudges yet",
            "dashboard.no_nudges_subtitle":     "Create your first nudge to get started",
            "dashboard.history":                "History",
            "dashboard.insights":               "Insights",
            "dashboard.total":                  "Total",
            "dashboard.done":                   "Done",
            "dashboard.streak":                 "Streak",
            "dashboard.nudges":                 "nudges",
            "dashboard.view_trends":            "View trends",
            // Settings – General
            "settings.title":                   "Settings",
            // Settings – Account
            "settings.account.section":         "ACCOUNT",
            "settings.account.pro_badge":       "Nudge Pro",
            "settings.account.free_badge":      "Free Plan",
            "settings.account.pro_subtitle":    "All features unlocked",
            "settings.account.free_subtitle":   "2 nudges / week",
            "settings.account.manage":          "Manage Subscription",
            "settings.account.upgrade":         "Upgrade to Pro",
            "settings.account.restore":         "Restore Purchases",
            // Settings – Language
            "settings.language.section":        "LANGUAGE",
            // Settings – Preferences
            "settings.preferences.section":     "PREFERENCES",
            "settings.preferences.appearance":   "Appearance",
            "settings.preferences.appearance_sub": "Choose your theme",
            "settings.preferences.system":       "System",
            "settings.preferences.light":        "Light",
            "settings.preferences.dark":         "Dark",
            "settings.preferences.haptics":     "Haptic Feedback",
            "settings.preferences.haptics_sub": "Feel a tap on completions",
            "settings.preferences.notifications": "Notifications",
            "settings.preferences.notifications_sub": "Reminders and updates",
            "settings.preferences.step_count": "Steps Per Nudge",
            "settings.preferences.step_count_sub": "How many steps the AI generates",
            // Settings – About
            "settings.about.section":           "ABOUT",
            "settings.about.how_it_works":      "How Nudge Works",
            "settings.about.rate":              "Rate Nudge ★",
            "settings.about.privacy":           "Privacy Policy",
            "settings.about.terms":             "Terms of Use",
            "settings.about.version":           "Version",
            // Settings – Data
            "settings.data.section":            "DATA",
            "settings.data.export":             "Export History",
            "settings.data.clear":              "Clear All Data",
            "settings.data.clear_title":        "Clear All Data?",
            "settings.data.clear_message":      "This will permanently delete all your nudge history. This cannot be undone.",
            "settings.data.clear_confirm":      "Delete Everything",
            "settings.data.cancel":             "Cancel",            // History
            "history.title":                    "History",
            "history.search":                   "Search tasks",
            "history.empty_title":              "No nudges yet",
            "history.empty_subtitle":           "Your completed nudges will\nappear here over time.",
            "history.filter_all":               "All Moods",
            // Details
            "details.title":                    "Details",
            "details.delete_title":             "Delete Nudge?",
            "details.delete_message":           "This nudge will be permanently removed.",
            "details.delete_button":            "Delete Nudge",
            "details.steps":                    "Steps",
            "details.goal":                     "Goal",
            "details.info":                     "Info",
            "details.created":                  "Created",
            "details.mood":                     "Mood",
            "details.energy":                   "Energy",
            "details.source":                   "Source",
            "details.completed":                "Completed",
            "details.source_manual":            "Manual",
            "details.source_template":          "Template",
            "details.mark_complete":            "Mark Complete",
            "details.mark_incomplete":          "Mark Incomplete",
            "details.tap_complete":             "Tap to complete",
            "details.not_found":                "Nudge not found",
            // Paywall
            "paywall.title_1":                  "GO ",
            "paywall.title_2":                  "PRO",
            "paywall.subtitle":                 "Remove limits. Nudge without friction.",
            "paywall.feature_unlimited_title":  "Unlimited Nudges",
            "paywall.feature_unlimited_sub":    "No weekly caps, ever",
            "paywall.feature_ai_title":         "Priority AI",
            "paywall.feature_ai_sub":           "Faster, smarter step generation",
            "paywall.feature_support_title":    "Support Indie Dev",
            "paywall.feature_support_sub":      "Keep Nudge alive and improving",
            "paywall.best_value":               "BEST VALUE",
            "paywall.per_year":                 "/year",
            "paywall.per_month":                "/month",
            "paywall.cta":                      "Continue",
            "paywall.restore":                  "Restore Purchases",
            "paywall.disclosure":               "Subscription auto-renews at the same price unless cancelled at least 24 hours before the end of the current period. Manage or cancel in App Store settings.",
            // Common
            "common.delete":                    "Delete",
            "common.cancel":                    "Cancel",
            "common.steps":                     "steps",
            "common.of":                        "of",
            // Dashboard extras
            "dashboard.no_nudges_on_day":       "No nudges on this day",
            "dashboard.nudge_singular":         "nudge",
            "dashboard.nudge_plural":           "nudges",
            // TipsSheet
            "tips.title":                       "How Nudge Works",
            "tips.done":                        "Done",
            "tips.intro":                       "Nudge breaks through procrastination with tiny, progressive steps tailored to how you feel.",
            "tips.step1_title":                 "Describe Your Task",
            "tips.step1_desc":                  "Tell Nudge what you’ve been putting off. The more detail, the better your steps.",
            "tips.step2_title":                 "Set Mood & Energy",
            "tips.step2_desc":                  "Pick your current mood and energy level. Nudge adapts: low energy gets gentler steps.",
            "tips.step3_title":                 "Get Your Action Plan",
            "tips.step3_desc":                  "4 progressive steps, each building on the last. From a tiny first move to real progress.",
            "tips.step4_title":                 "Track Your Progress",
            "tips.step4_desc":                  "See streaks, completion rate, and mood patterns. Build momentum over time.",
            "tips.protip_title":                "Pro tip",
            "tips.protip_body":                 "Done beats perfect. A rough start is infinitely better than a perfect plan you never begin.",
            // Input Flow
            "flow.step1_label":                 "Step 1",
            "flow.step2_label":                 "Step 2",
            "flow.step3_label":                 "Step 3",
            "flow.task_title":                  "What are you\nputting off?",
            "flow.task_subtitle":               "Describe the task you keep avoiding.",
            "flow.task_placeholder":            "e.g., Start writing my essay, clean up the kitchen...",
            "flow.task_too_long":               "Try to keep it concise",
            "flow.energy_title":                "How’s your\nenergy?",
            "flow.energy_subtitle":             "This helps tailor the nudge to what you can handle.",
            "flow.mood_title":                  "What’s your\nmood?",
            "flow.mood_subtitle":               "Pick what feels closest right now.",
            "flow.next":                        "Next",
            "flow.back":                        "Back",
            "flow.nudge_me":                    "Nudge Me",
            // Energy Descriptions
            "energy.very_low":                  "Barely keeping eyes open.",
            "energy.low":                       "Running low. Gentle actions only.",
            "energy.medium":                    "Functional. Can handle a moderate nudge.",
            "energy.high":                      "Feeling capable. Ready for a solid push.",
            "energy.very_high":                 "Full battery. Can take on a sprint.",
            // Manual Missions
            "manual.title":                     "Create Your Missions",
            "manual.subtitle":                  "Both AI models are unavailable right now.\nBreak your task into 5 small missions instead.",
            "manual.create":                    "Create Plan",
            "manual.mission_label":             "Mission",
            "manual.filled_format":             "/5 missions filled",
            // Result View
            "result.action_plan":               "Your Action Plan",
            "result.steps":                     "Steps",
            "result.goal":                      "Goal",
            "result.all_done":                  "All done!",
            "result.save_close":                "Save & Close",
            "result.start_over":                "Start Over",
            "result.error_title":               "Something went wrong",
            "result.tap_complete":              "Tap to complete",
            // Stats / Insights
            "stats.title":                      "Insights",
            "stats.empty_title":                "No insights yet",
            "stats.empty_subtitle":             "Complete your first nudge\nand trends will appear here.",
            "stats.weekly":                     "WEEKLY ACTIVITY",
            "stats.completion_breakdown":       "COMPLETION BREAKDOWN",
            "stats.mood_section":               "MOOD WHEN PROCRASTINATING",
            "stats.friction":                   "COMMON FRICTION TYPES",
            "stats.improve":                    "HOW TO IMPROVE",
            "stats.completed":                  "Completed",
            "stats.in_progress":                "In Progress",
            "stats.not_started":                "Not Started",
            "stats.total_label":                "total",
            "stats.generating":                 "Generating your insight...",
            "stats.no_data":                    "No data yet",
            "stats.no_insight":                 "Keep creating nudges — your personalised reduction plan will appear here once you have more data.",
            "stats.unlock_title":               "Unlock Full Insights",
            "stats.unlock_body":                "Upgrade to Pro to see all your\ntrends, moods, and patterns.",
            "stats.upgrade":                    "Upgrade",
        ],

        // ─────────────────────────────────────────────────────────────────
        .spanish: [
            // Dashboard
            "dashboard.greeting.morning":       "BUENOS DÍAS",
            "dashboard.greeting.afternoon":     "BUENAS TARDES",
            "dashboard.greeting.evening":       "BUENAS NOCHES",
            "dashboard.new_nudge":              "Nuevo Nudge",
            "dashboard.new_nudge_subtitle":     "Comienza tu siguiente tarea",
            "dashboard.recent":                 "RECIENTE",
            "dashboard.view_all":               "Ver todo",
            "dashboard.calendar":               "CALENDARIO",
            "dashboard.no_nudges_title":        "Sin nudges aún",
            "dashboard.no_nudges_subtitle":     "Crea tu primer nudge para comenzar",
            "dashboard.history":                "Historial",
            "dashboard.insights":               "Estadísticas",
            "dashboard.total":                  "Total",
            "dashboard.done":                   "Hecho",
            "dashboard.streak":                 "Racha",
            "dashboard.nudges":                 "nudges",
            "dashboard.view_trends":            "Ver tendencias",
            // Settings – General
            "settings.title":                   "Ajustes",
            // Settings – Account
            "settings.account.section":         "CUENTA",
            "settings.account.pro_badge":       "Nudge Pro",
            "settings.account.free_badge":      "Plan Gratuito",
            "settings.account.pro_subtitle":    "Todas las funciones desbloqueadas",
            "settings.account.free_subtitle":   "2 nudges / semana",
            "settings.account.manage":          "Gestionar Suscripción",
            "settings.account.upgrade":         "Mejorar a Pro",
            "settings.account.restore":         "Restaurar Compras",
            // Settings – Language
            "settings.language.section":        "IDIOMA",
            // Settings – Preferences
            "settings.preferences.section":     "PREFERENCIAS",
            "settings.preferences.appearance":   "Apariencia",
            "settings.preferences.appearance_sub": "Elige tu tema",
            "settings.preferences.system":       "Sistema",
            "settings.preferences.light":        "Claro",
            "settings.preferences.dark":         "Oscuro",
            "settings.preferences.haptics":     "Retroalimentación Háptica",
            "settings.preferences.haptics_sub": "Siente una vibración al completar",
            "settings.preferences.notifications": "Notificaciones",
            "settings.preferences.notifications_sub": "Recordatorios y actualizaciones",
            "settings.preferences.step_count": "Pasos por Empujón",
            "settings.preferences.step_count_sub": "Cuántos pasos genera la IA",
            // Settings – About
            "settings.about.section":           "ACERCA DE",
            "settings.about.how_it_works":      "Cómo Funciona Nudge",
            "settings.about.rate":              "Valorar Nudge ★",
            "settings.about.privacy":           "Política de Privacidad",
            "settings.about.terms":             "Términos de Uso",
            "settings.about.version":           "Versión",
            // Settings – Data
            "settings.data.section":            "DATOS",
            "settings.data.export":             "Exportar Historial",
            "settings.data.clear":              "Borrar Todos los Datos",
            "settings.data.clear_title":        "¿Borrar Todos los Datos?",
            "settings.data.clear_message":      "Esto eliminará permanentemente todo tu historial de nudges. No se puede deshacer.",
            "settings.data.clear_confirm":      "Eliminar Todo",
            "settings.data.cancel":             "Cancelar",            // History
            "history.title":                    "Historial",
            "history.search":                   "Buscar tareas",
            "history.empty_title":              "Sin nudges aún",
            "history.empty_subtitle":           "Tus nudges completados\naparecerán aquí con el tiempo.",
            "history.filter_all":               "Todos los estados",
            // Details
            "details.title":                    "Detalles",
            "details.delete_title":             "¿Eliminar Nudge?",
            "details.delete_message":           "Este nudge será eliminado permanentemente.",
            "details.delete_button":            "Eliminar Nudge",
            "details.steps":                    "Pasos",
            "details.goal":                     "Meta",
            "details.info":                     "Info",
            "details.created":                  "Creado",
            "details.mood":                     "Estado",
            "details.energy":                   "Energía",
            "details.source":                   "Fuente",
            "details.completed":                "Completado",
            "details.source_manual":            "Manual",
            "details.source_template":          "Plantilla",
            "details.mark_complete":            "Marcar Completado",
            "details.mark_incomplete":          "Marcar Incompleto",
            "details.tap_complete":             "Toca para completar",
            "details.not_found":                "Nudge no encontrado",
            // Paywall
            "paywall.title_1":                  "HAZTE ",
            "paywall.title_2":                  "PRO",
            "paywall.subtitle":                 "Sin límites. Nudge sin fricción.",
            "paywall.feature_unlimited_title":  "Nudges Ilimitados",
            "paywall.feature_unlimited_sub":    "Sin límites semanales",
            "paywall.feature_ai_title":         "IA Prioritaria",
            "paywall.feature_ai_sub":           "Generación de pasos más rápida",
            "paywall.feature_support_title":    "Apoya al Desarrollador",
            "paywall.feature_support_sub":      "Mantén Nudge vivo y mejorando",
            "paywall.best_value":               "MEJOR PRECIO",
            "paywall.per_year":                 "/año",
            "paywall.per_month":                "/mes",
            "paywall.cta":                      "Continuar",
            "paywall.restore":                  "Restaurar Compras",
            "paywall.disclosure":               "La suscripción se renueva automáticamente al mismo precio salvo cancelación 24 horas antes del fin del período actual. Gestionar en App Store.",
            // Common
            "common.delete":                    "Eliminar",
            "common.cancel":                    "Cancelar",
            "common.steps":                     "pasos",
            "common.of":                        "de",
            // Dashboard extras
            "dashboard.no_nudges_on_day":       "Sin nudges este día",
            "dashboard.nudge_singular":         "nudge",
            "dashboard.nudge_plural":           "nudges",
            // TipsSheet
            "tips.title":                       "Cómo Funciona Nudge",
            "tips.done":                        "Listo",
            "tips.intro":                       "Nudge rompe la procrastinación con pequeños pasos progresivos adaptados a cómo te sientes.",
            "tips.step1_title":                 "Describe tu Tarea",
            "tips.step1_desc":                  "Dile a Nudge lo que has estado postergando. Cuanto más detalle, mejores serán tus pasos.",
            "tips.step2_title":                 "Elige Estado y Energía",
            "tips.step2_desc":                  "Elige tu estado de ánimo y nivel de energía. Nudge se adapta: menos energía, pasos más suaves.",
            "tips.step3_title":                 "Obtén tu Plan de Acción",
            "tips.step3_desc":                  "4 pasos progresivos, cada uno en el anterior. Desde un pequeño inicio hasta el progreso real.",
            "tips.step4_title":                 "Sigue tu Progreso",
            "tips.step4_desc":                  "Ve rachas, tasa de finalización y patrones de estado. Construye impulso con el tiempo.",
            "tips.protip_title":                "Consejo Pro",
            "tips.protip_body":                 "Hecho supera a perfecto. Un inicio imperfecto es mejor que un plan perfecto que nunca comienzas.",
            // Input Flow
            "flow.step1_label":                 "Paso 1",
            "flow.step2_label":                 "Paso 2",
            "flow.step3_label":                 "Paso 3",
            "flow.task_title":                  "¿Qué estás\nevitando?",
            "flow.task_subtitle":               "Describe la tarea que sigues postergando.",
            "flow.task_placeholder":            "ej., Empezar a escribir mi ensayo, limpiar la cocina...",
            "flow.task_too_long":               "Intenta ser más conciso",
            "flow.energy_title":                "¿Cómo está tu\nenergía?",
            "flow.energy_subtitle":             "Esto ayuda a adaptar el nudge a lo que puedes manejar.",
            "flow.mood_title":                  "¿Cómo está tu\nestado de ánimo?",
            "flow.mood_subtitle":               "Elige lo que más se acerca a cómo te sientes ahora.",
            "flow.next":                        "Siguiente",
            "flow.back":                        "Atrás",
            "flow.nudge_me":                    "Empújame",
            // Energy Descriptions
            "energy.very_low":                  "Apenas manteniendo los ojos abiertos.",
            "energy.low":                       "Bajo nivel. Solo acciones suaves.",
            "energy.medium":                    "Funcional. Puedo manejar un nudge moderado.",
            "energy.high":                      "Me siento capaz. Listo para un empújón sólido.",
            "energy.very_high":                 "Batería llena. Puedo afrontar un sprint.",
            // Manual Missions
            "manual.title":                     "Crea tus Misiones",
            "manual.subtitle":                  "Ambos modelos de IA no están disponibles.\nDivide tu tarea en 5 pequeñas misiones.",
            "manual.create":                    "Crear Plan",
            "manual.mission_label":             "Misión",
            "manual.filled_format":             "/5 misiones completadas",
            // Result View
            "result.action_plan":               "Tu Plan de Acción",
            "result.steps":                     "Pasos",
            "result.goal":                      "Meta",
            "result.all_done":                  "¡Todo listo!",
            "result.save_close":                "Guardar y Cerrar",
            "result.start_over":                "Empezar de Nuevo",
            "result.error_title":               "Algo salió mal",
            "result.tap_complete":              "Toca para completar",
            // Stats / Insights
            "stats.title":                      "Estadísticas",
            "stats.empty_title":                "Sin estadísticas aún",
            "stats.empty_subtitle":             "Completa tu primer nudge\ny las tendencias aparecerán aquí.",
            "stats.weekly":                     "ACTIVIDAD SEMANAL",
            "stats.completion_breakdown":       "DESGLOSE DE COMPLETADOS",
            "stats.mood_section":               "ESTADO AL PROCRASTINAR",
            "stats.friction":                   "TIPOS DE FRICCIÓN COMUNES",
            "stats.improve":                    "CÓMO MEJORAR",
            "stats.completed":                  "Completado",
            "stats.in_progress":                "En Progreso",
            "stats.not_started":                "No Iniciado",
            "stats.total_label":                "total",
            "stats.generating":                 "Generando tu estadística...",
            "stats.no_data":                    "Sin datos aún",
            "stats.no_insight":                 "Sigue creando nudges: tu plan de reducción personalizado aparecerá aquí cuando tengas más datos.",
            "stats.unlock_title":               "Desbloquea Estadísticas Completas",
            "stats.unlock_body":                "Mejora a Pro para ver todas tus\ntendencias, estados y patrones.",
            "stats.upgrade":                    "Mejorar",
        ],

        // ─────────────────────────────────────────────────────────────────
        .french: [
            // Dashboard
            "dashboard.greeting.morning":       "BONJOUR",
            "dashboard.greeting.afternoon":     "BON APRÈS-MIDI",
            "dashboard.greeting.evening":       "BONSOIR",
            "dashboard.new_nudge":              "Nouveau Nudge",
            "dashboard.new_nudge_subtitle":     "Commencez votre prochaine tâche",
            "dashboard.recent":                 "RÉCENT",
            "dashboard.view_all":               "Voir tout",
            "dashboard.calendar":               "CALENDRIER",
            "dashboard.no_nudges_title":        "Pas encore de nudges",
            "dashboard.no_nudges_subtitle":     "Créez votre premier nudge pour commencer",
            "dashboard.history":                "Historique",
            "dashboard.insights":               "Statistiques",
            "dashboard.total":                  "Total",
            "dashboard.done":                   "Fait",
            "dashboard.streak":                 "Série",
            "dashboard.nudges":                 "nudges",
            "dashboard.view_trends":            "Voir les tendances",
            // Settings – General
            "settings.title":                   "Réglages",
            // Settings – Account
            "settings.account.section":         "COMPTE",
            "settings.account.pro_badge":       "Nudge Pro",
            "settings.account.free_badge":      "Plan Gratuit",
            "settings.account.pro_subtitle":    "Toutes les fonctionnalités débloquées",
            "settings.account.free_subtitle":   "2 nudges / semaine",
            "settings.account.manage":          "Gérer l'Abonnement",
            "settings.account.upgrade":         "Passer à Pro",
            "settings.account.restore":         "Restaurer les Achats",
            // Settings – Language
            "settings.language.section":        "LANGUE",
            // Settings – Preferences
            "settings.preferences.section":     "PRÉFÉRENCES",
            "settings.preferences.appearance":   "Apparence",
            "settings.preferences.appearance_sub": "Choisissez votre thème",
            "settings.preferences.system":       "Système",
            "settings.preferences.light":        "Clair",
            "settings.preferences.dark":         "Sombre",
            "settings.preferences.haptics":     "Retour Haptique",
            "settings.preferences.haptics_sub": "Sentir une vibration à la complétion",
            "settings.preferences.notifications": "Notifications",
            "settings.preferences.notifications_sub": "Rappels et mises à jour",
            "settings.preferences.step_count": "Étapes par Nudge",
            "settings.preferences.step_count_sub": "Nombre d'étapes générées par l'IA",
            // Settings – About
            "settings.about.section":           "À PROPOS",
            "settings.about.how_it_works":      "Comment Fonctionne Nudge",
            "settings.about.rate":              "Évaluer Nudge ★",
            "settings.about.privacy":           "Politique de Confidentialité",
            "settings.about.terms":             "Conditions d'Utilisation",
            "settings.about.version":           "Version",
            // Settings – Data
            "settings.data.section":            "DONNÉES",
            "settings.data.export":             "Exporter l'Historique",
            "settings.data.clear":              "Effacer Toutes les Données",
            "settings.data.clear_title":        "Effacer Toutes les Données ?",
            "settings.data.clear_message":      "Cela supprimera définitivement tout votre historique de nudges. Cette action est irréversible.",
            "settings.data.clear_confirm":      "Tout Supprimer",
            "settings.data.cancel":             "Annuler",            // History
            "history.title":                    "Historique",
            "history.search":                   "Rechercher des tâches",
            "history.empty_title":              "Pas encore de nudges",
            "history.empty_subtitle":           "Vos nudges complétés\napparaîtront ici avec le temps.",
            "history.filter_all":               "Toutes les humeurs",
            // Details
            "details.title":                    "Détails",
            "details.delete_title":             "Supprimer le Nudge ?",
            "details.delete_message":           "Ce nudge sera supprimé définitivement.",
            "details.delete_button":            "Supprimer le Nudge",
            "details.steps":                    "Étapes",
            "details.goal":                     "Objectif",
            "details.info":                     "Info",
            "details.created":                  "Créé le",
            "details.mood":                     "Humeur",
            "details.energy":                   "Énergie",
            "details.source":                   "Source",
            "details.completed":                "Complété",
            "details.source_manual":            "Manuel",
            "details.source_template":          "Modèle",
            "details.mark_complete":            "Marquer Complété",
            "details.mark_incomplete":          "Marquer Incomplet",
            "details.tap_complete":             "Appuyer pour compléter",
            "details.not_found":                "Nudge introuvable",
            // Paywall
            "paywall.title_1":                  "PASSER ",
            "paywall.title_2":                  "PRO",
            "paywall.subtitle":                 "Sans limites. Nudge sans friction.",
            "paywall.feature_unlimited_title":  "Nudges Illimités",
            "paywall.feature_unlimited_sub":    "Aucun plafond hebdomadaire",
            "paywall.feature_ai_title":         "IA Prioritaire",
            "paywall.feature_ai_sub":           "Génération d'étapes plus rapide",
            "paywall.feature_support_title":    "Soutenir le Développeur",
            "paywall.feature_support_sub":      "Gardez Nudge vivant et en progrès",
            "paywall.best_value":               "MEILLEURE OFFRE",
            "paywall.per_year":                 "/an",
            "paywall.per_month":                "/mois",
            "paywall.cta":                      "Continuer",
            "paywall.restore":                  "Restaurer les Achats",
            "paywall.disclosure":               "L'abonnement se renouvelle automatiquement au même prix sauf annulation 24 heures avant la fin de la période en cours. Gérer dans les réglages de l'App Store.",
            // Common
            "common.delete":                    "Supprimer",
            "common.cancel":                    "Annuler",
            "common.steps":                     "étapes",
            "common.of":                        "sur",
            // Dashboard extras
            "dashboard.no_nudges_on_day":       "Aucun nudge ce jour",
            "dashboard.nudge_singular":         "nudge",
            "dashboard.nudge_plural":           "nudges",
            // TipsSheet
            "tips.title":                       "Comment Fonctionne Nudge",
            "tips.done":                        "Terminé",
            "tips.intro":                       "Nudge brise la procrastination avec de petites étapes progressives adaptées à votre état.",
            "tips.step1_title":                 "Décrivez votre Tâche",
            "tips.step1_desc":                  "Dites à Nudge ce que vous repoussez. Plus de détails, de meilleures étapes.",
            "tips.step2_title":                 "Choisissez Humeur et Énergie",
            "tips.step2_desc":                  "Choisissez votre humeur et niveau d’énergie. Nudge s’adapte : étapes plus douces si moins d’énergie.",
            "tips.step3_title":                 "Obtenez votre Plan d’Action",
            "tips.step3_desc":                  "4 étapes progressives, chacune construite sur la précédente. Du premier pas au vrai progrès.",
            "tips.step4_title":                 "Suivez votre Progression",
            "tips.step4_desc":                  "Voyez les séries, le taux de complétion et les patterns d’humeur. Construisez de l’élan.",
            "tips.protip_title":                "Conseil Pro",
            "tips.protip_body":                 "Fait vaut mieux que parfait. Un début imparfait est mieux qu’un plan parfait que vous ne commencez jamais.",
            // Input Flow
            "flow.step1_label":                 "Étape 1",
            "flow.step2_label":                 "Étape 2",
            "flow.step3_label":                 "Étape 3",
            "flow.task_title":                  "Qu’est-ce que vous\nremettez à plus tard ?",
            "flow.task_subtitle":               "Décrivez la tâche que vous continuez à reporter.",
            "flow.task_placeholder":            "ex., Commencer à rédiger mon essai, nettoyer la cuisine...",
            "flow.task_too_long":               "Essayez d’être plus concis",
            "flow.energy_title":                "Comment est votre\nénergie ?",
            "flow.energy_subtitle":             "Cela aide à adapter le nudge à ce que vous pouvez gérer.",
            "flow.mood_title":                  "Quelle est votre\nhumeur ?",
            "flow.mood_subtitle":               "Choisissez ce qui se rapproche le plus de maintenant.",
            "flow.next":                        "Suivant",
            "flow.back":                        "Retour",
            "flow.nudge_me":                    "Nudge-moi",
            // Energy Descriptions
            "energy.very_low":                  "À peine les yeux ouverts.",
            "energy.low":                       "Bas niveau. Actions douces seulement.",
            "energy.medium":                    "Fonctionnel. Peut gérer un nudge modéré.",
            "energy.high":                      "Me sens capable. Prêt pour une bonne poussée.",
            "energy.very_high":                 "Pleine batterie. Prêt pour un sprint.",
            // Manual Missions
            "manual.title":                     "Créez vos Missions",
            "manual.subtitle":                  "Les deux modèles IA sont indisponibles.\nDivisez votre tâche en 5 petites missions.",
            "manual.create":                    "Créer le Plan",
            "manual.mission_label":             "Mission",
            "manual.filled_format":             "/5 missions remplies",
            // Result View
            "result.action_plan":               "Votre Plan d’Action",
            "result.steps":                     "Étapes",
            "result.goal":                      "Objectif",
            "result.all_done":                  "Tout fait !",
            "result.save_close":                "Enregistrer et Fermer",
            "result.start_over":                "Recommencer",
            "result.error_title":               "Quelque chose s’est mal passé",
            "result.tap_complete":              "Appuyer pour compléter",
            // Stats / Insights
            "stats.title":                      "Statistiques",
            "stats.empty_title":                "Pas encore de statistiques",
            "stats.empty_subtitle":             "Complétez votre premier nudge\net les tendances apparaîtront ici.",
            "stats.weekly":                     "ACTIVITÉ HEBDOMADAIRE",
            "stats.completion_breakdown":       "RÉPARTITION DES COMPLÉTÉS",
            "stats.mood_section":               "HUMEUR EN PROCRASTINANT",
            "stats.friction":                   "TYPES DE FRICTION COURANTS",
            "stats.improve":                    "COMMENT S’AMÉLIORER",
            "stats.completed":                  "Complété",
            "stats.in_progress":                "En Cours",
            "stats.not_started":                "Non Commencé",
            "stats.total_label":                "total",
            "stats.generating":                 "Génération de votre statistique...",
            "stats.no_data":                    "Pas encore de données",
            "stats.no_insight":                 "Continuez à créer des nudges : votre plan personnalisé apparaêtra ici avec plus de données.",
            "stats.unlock_title":               "Débloquez les Statistiques Complètes",
            "stats.unlock_body":                "Passez à Pro pour voir toutes vos\ntendances, humeurs et patterns.",
            "stats.upgrade":                    "Améliorer",
        ],
    ]
    // swiftlint:enable line_length
}

// MARK: - Environment Key

private struct LanguageManagerKey: EnvironmentKey {
    static let defaultValue: LanguageManager = .shared
}

extension EnvironmentValues {
    var languageManager: LanguageManager {
        get { self[LanguageManagerKey.self] }
        set { self[LanguageManagerKey.self] = newValue }
    }
}
