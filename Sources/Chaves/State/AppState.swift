import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var keys: [KeyRecord] = []
    @Published var stats: VaultStats = VaultStats(configured: 0, total: 0, missing: 0, withCredit: 0)
    @Published var store: StoreInfo?
    @Published var creditsUpdatedAt: String?
    @Published var query = ""
    @Published var filter: SidebarFilter = .all
    @Published var selectedName: String?
    @Published var isLoading = false
    @Published var isRefreshingCredits = false
    @Published var banner: String?
    @Published var isEditorPresented = false
    @Published var editorName = ""
    @Published var editorValue = ""
    @Published var mongoOK = false

    func bootstrap() {
        reload()
    }

    var visibleKeys: [KeyRecord] {
        keys.filter { filter.matches($0) && matchesQuery($0) }
    }

    var selectedKey: KeyRecord? {
        keys.first { $0.name == selectedName } ?? visibleKeys.first
    }

    func reload() {
        isLoading = true
        banner = nil
        Task {
            do {
                let payload = try await Task.detached { try VaultClient.list(credits: true, refresh: false) }.value
                apply(payload)
                mongoOK = payload.ok
            } catch {
                banner = error.localizedDescription
                mongoOK = false
            }
            isLoading = false
        }
    }

    func refreshCredits() {
        isRefreshingCredits = true
        banner = nil
        Task {
            do {
                let payload = try await Task.detached { try VaultClient.list(credits: true, refresh: true) }.value
                apply(payload)
                banner = "Saldos atualizados."
            } catch {
                banner = error.localizedDescription
            }
            isRefreshingCredits = false
        }
    }

    func saveEditor() {
        let name = editorName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let value = editorValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !value.isEmpty else {
            banner = "Nome e valor precisam estar preenchidos."
            return
        }
        Task {
            do {
                let result = try await Task.detached { try VaultClient.upsert(name: name, value: value) }.value
                if result.ok {
                    editorValue = ""
                    isEditorPresented = false
                    banner = "\(name) gravada. O valor completo não aparece na lista."
                    reload()
                } else {
                    banner = result.error ?? "Não gravou."
                }
            } catch {
                banner = error.localizedDescription
            }
        }
    }

    func deleteSelected() {
        guard let name = selectedName else { return }
        Task {
            do {
                _ = try await Task.detached { try VaultClient.delete(name: name) }.value
                banner = "\(name) saiu do cofre."
                selectedName = nil
                reload()
            } catch {
                banner = error.localizedDescription
            }
        }
    }

    private func apply(_ payload: VaultPayload) {
        keys = payload.keys
        stats = payload.stats
        store = payload.store
        creditsUpdatedAt = payload.credits?.updatedAt
        if selectedName == nil {
            selectedName = payload.keys.first(where: \.configured)?.name ?? payload.keys.first?.name
        }
    }

    private func matchesQuery(_ key: KeyRecord) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let haystack = "\(key.name) \(key.label) \(key.hint) \(key.categoryLabel)".lowercased()
        return haystack.contains(needle.lowercased())
    }
}
