import SwiftUI
import Combine
import RevenueCat

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published State

    @Published fileprivate var _isProUser: Bool = false
    /// True if the user has an active Pro entitlement, OR if debug force-Pro is on.
    var isProUser: Bool { debugForceProUser || _isProUser }
    @Published fileprivate(set) var customerInfo: CustomerInfo? = nil
    @Published private(set) var offerings: Offerings? = nil
    @Published private(set) var isLoading: Bool = true

    // MARK: - Constants

    static var apiKey: String {
        return (Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String) ?? ""
    }

    static let entitlementID = "Nudge Pro"
    static let monthlyProductID = "com.BenjaminBelloeil.Nudge.monthly"
    static let yearlyProductID = "com.BenjaminBelloeil.Nudge.yearly"

    // Free tier limit
    static let freeNudgesPerWeek = 3

    // MARK: - Init

    private(set) var isConfigured = false

    private init() {}

    // MARK: - Configure

    func configure() {
        let key = Self.apiKey
        #if !DEBUG
        // RevenueCat hard-crashes Release builds if a test_ key is used — skip gracefully
        guard !key.isEmpty && !key.hasPrefix("test_") else {
            isLoading = false
            return
        }
        #else
        guard !key.isEmpty else {
            isLoading = false
            return
        }
        #endif
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: key)
        Purchases.shared.delegate = RevenueCatDelegate.shared
        isConfigured = true

        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
            isLoading = false
        }
    }

    // MARK: - Refresh

    func refreshCustomerInfo() async {
        guard isConfigured else { return }
        do {
            // Use .fetchCurrent to always hit the server, bypassing RevenueCat's local cache
            let info = try await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent)
            #if DEBUG
            print("━━━━━━━━━━━━ RevenueCat customerInfo ━━━━━━━━━━━━")
            print("🟣 ALL entitlement keys:", Array(info.entitlements.all.keys))
            print("🟢 ACTIVE entitlement keys:", Array(info.entitlements.active.keys))
            print("🎯 Looking for entitlement ID: '\(Self.entitlementID)'")
            print("🔍 isProUser:", info.entitlements[Self.entitlementID]?.isActive == true)
            print("🗓️ expiration:", info.entitlements[Self.entitlementID]?.expirationDate as Any)
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif
            self.customerInfo = info
            self._isProUser = info.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            // Fail silently — keep current state
        }
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async {
        guard isConfigured else { return }
        do {
            self.offerings = try await Purchases.shared.offerings()
        } catch {
            // Fail silently
        }
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> Bool {
        guard isConfigured else { throw NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subscriptions unavailable"]) }
        let result = try await Purchases.shared.purchase(package: package)
        self.customerInfo = result.customerInfo
        self._isProUser = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        return !result.userCancelled
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        guard isConfigured else { throw NSError(domain: "SubscriptionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subscriptions unavailable"]) }
        let info = try await Purchases.shared.restorePurchases()
        self.customerInfo = info
        self._isProUser = info.entitlements[Self.entitlementID]?.isActive == true
    }

    // MARK: - Gating Logic

    // Keys for the permanent weekly creation counter
    private static let nudgeCreationCountKey  = "nudge.weeklyCreations.count"
    private static let nudgeCreationWeekKey   = "nudge.weeklyCreations.weekStart"

    /// How many nudges the user has CREATED this week (never decrements on delete).
    func nudgesCreatedThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        let defaults = UserDefaults.standard
        if let storedWeekStart = defaults.object(forKey: Self.nudgeCreationWeekKey) as? Date,
           calendar.isDate(storedWeekStart, inSameDayAs: weekStart) {
            return defaults.integer(forKey: Self.nudgeCreationCountKey)
        } else {
            // New week — reset counter
            defaults.set(weekStart, forKey: Self.nudgeCreationWeekKey)
            defaults.set(0, forKey: Self.nudgeCreationCountKey)
            return 0
        }
    }

    /// Call once when a nudge is first saved. Increments the permanent counter.
    func recordNudgeCreated() {
        let current = nudgesCreatedThisWeek()
        UserDefaults.standard.set(current + 1, forKey: Self.nudgeCreationCountKey)
    }

    /// Legacy helper kept for CustomerCenterView display (reflects live entries).
    func nudgesThisWeek() -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return PersistenceManager.shared.entries.filter { $0.createdAt >= weekStart }.count
    }

    // DEBUG ONLY: set to true in Simulator/device to bypass paywall while testing UI
    @AppStorage("debug_forceProUser") var debugForceProUser: Bool = false

    func canCreateNudge() -> Bool {
        if debugForceProUser { return true }
        // While RevenueCat is still loading, don't block the user
        if isLoading { return true }
        if isProUser { return true }
        return nudgesCreatedThisWeek() < Self.freeNudgesPerWeek
    }

    var remainingFreeNudges: Int {
        if debugForceProUser { return Int.max }
        if isLoading { return Int.max }
        return max(0, Self.freeNudgesPerWeek - nudgesCreatedThisWeek())
    }

    // MARK: - Pro AI Daily Limit

    static let proAIDailyLimit = 50
    private static let aiDailyCountKey = "nudge.aiDaily.count"
    private static let aiDailyDateKey  = "nudge.aiDaily.date"

    func aiNudgesGeneratedToday() -> Int {
        let stored = UserDefaults.standard.string(forKey: Self.aiDailyDateKey) ?? ""
        let today  = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        guard stored == today else { return 0 }
        return UserDefaults.standard.integer(forKey: Self.aiDailyCountKey)
    }

    func recordAINudgeGenerated() {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        UserDefaults.standard.set(today, forKey: Self.aiDailyDateKey)
        UserDefaults.standard.set(aiNudgesGeneratedToday() + 1, forKey: Self.aiDailyCountKey)
    }

    func canGenerateWithAI() -> Bool {
        guard isProUser else { return true }
        return aiNudgesGeneratedToday() < Self.proAIDailyLimit
    }
}

// MARK: - RevenueCat Delegate

final class RevenueCatDelegate: NSObject, PurchasesDelegate, Sendable {
    static let shared = RevenueCatDelegate()

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            SubscriptionManager.shared.customerInfo = customerInfo
            SubscriptionManager.shared._isProUser = customerInfo.entitlements[SubscriptionManager.entitlementID]?.isActive == true
        }
    }
}
