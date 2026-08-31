import Foundation
import Observation
import OSLog
import Security

/// API keys for the providers. They live in the Keychain, never in UserDefaults
/// or a JSON file next to the history — a leaked key costs the user real money.
/// Only a masked form ever reaches the interface.
@MainActor
@Observable
final class ProviderKeyStore {
    /// What the last check against the provider said.
    enum Status: Equatable {
        case idle
        case checking
        case ok(models: Int)
        case failed(ProviderClient.Failure)
    }

    /// Provider id → key. Kept in memory so the UI doesn't hit the Keychain on
    /// every redraw; the Keychain stays the source of truth on disk.
    private(set) var keys: [String: String] = [:]
    private(set) var status: [String: Status] = [:]
    /// Models as the provider last reported them. Cached in UserDefaults (they
    /// are not secret) so the dropdowns work offline and on the next launch.
    private(set) var models: [String: [ProviderModel]] = [:]

    @ObservationIgnored private let log = Logger(category: "ProviderKeyStore")

    private static let service = "com.v0ca.app.providers"
    private static let modelsKey = "providerModels"

    init() {
        for provider in ProviderCatalog.all {
            if let key = Self.read(account: provider.id) {
                keys[provider.id] = key
            }
        }
        if let data = UserDefaults.standard.data(forKey: Self.modelsKey),
           let cached = try? JSONDecoder().decode([String: [ProviderModel]].self, from: data) {
            models = cached
        }
    }

    /// Checks the key against the provider and, on success, stores it. A key is
    /// only saved once it has proven to work — otherwise the green "connected"
    /// card would be a lie.
    func verify(_ provider: Provider, key: String) async {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        status[provider.id] = .checking
        do {
            let fetched = try await ProviderClient.listModels(provider, key: trimmed)
            Self.write(trimmed, account: provider.id)
            keys[provider.id] = trimmed
            models[provider.id] = fetched
            saveModels()
            status[provider.id] = .ok(models: fetched.count)
        } catch let failure as ProviderClient.Failure {
            status[provider.id] = .failed(failure)
        } catch {
            status[provider.id] = .failed(.malformed)
        }
    }

    /// Providers with a working key, in catalog order. A provider whose module
    /// is off drops out here — its key stays in the Keychain untouched, ready
    /// for the moment the module comes back.
    var connectedProviders: [Provider] {
        ProviderCatalog.available.filter { isConnected($0.id) }
    }

    /// Models of one provider. `visionOnly` drops the ones the provider
    /// explicitly marks as not accepting images; models that say nothing about
    /// it stay in the list.
    ///
    /// Deliberately per provider: a model is picked inside the provider that
    /// answers for it, so two providers offering the same model name (an
    /// aggregator next to a direct key) can't be confused for one another.
    /// `featuredOnly` keeps the recognized families only — see `ModelShortlist`.
    /// If the shortlist matches nothing (an unknown provider, a catalog that
    /// names things its own way), the full list is returned rather than an empty
    /// picker: an empty list would look like a broken key.
    func modelList(
        of providerID: String,
        visionOnly: Bool,
        featuredOnly: Bool = false
    ) -> [ProviderModel] {
        let all = (models[providerID] ?? []).filter { !visionOnly || $0.vision != false }
        guard featuredOnly else { return all }
        let featured = ModelShortlist.featured(all)
        return featured.isEmpty ? all : featured
    }

    func isConnected(_ providerID: String) -> Bool {
        keys[providerID] != nil
    }

    /// "sk-proj-•••••4f2a": enough of the head to tell the providers apart and
    /// enough of the tail to tell two keys of the same provider apart.
    func masked(_ providerID: String) -> String? {
        guard let key = keys[providerID] else { return nil }
        guard key.count > 12 else { return String(repeating: "•", count: max(key.count, 8)) }
        return key.prefix(8) + "•••••" + key.suffix(4)
    }

    func remove(_ providerID: String) {
        Self.delete(account: providerID)
        keys[providerID] = nil
        models[providerID] = nil
        status[providerID] = nil
        saveModels()
    }

    private func saveModels() {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: Self.modelsKey)
    }

    // MARK: - Keychain

    private static func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read(account: String) -> String? {
        var query = query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query = query(account: account)
        // Update first: SecItemAdd fails with errSecDuplicateItem on a replace.
        let updated = SecItemUpdate(
            query as CFDictionary, [kSecValueData as String: data] as CFDictionary
        )
        guard updated != errSecSuccess else { return }
        var insert = query
        insert[kSecValueData as String] = data
        // The key is only needed while the user is at the Mac, and it must not
        // travel to other devices in an iCloud Keychain.
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        SecItemAdd(insert as CFDictionary, nil)
    }

    private static func delete(account: String) {
        SecItemDelete(query(account: account) as CFDictionary)
    }
}
