import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            List(SidebarFilter.allCases, selection: $state.filter) { filter in
                Label(filter.title, systemImage: filter.symbol)
                    .tag(filter)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .safeAreaInset(edge: .bottom) {
                StoreStatusPanel()
                    .padding(12)
            }
        } content: {
            VStack(spacing: 0) {
                StatsBar()
                if let banner = state.banner {
                    Text(banner)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12))
                }
                KeysListView()
            }
            .navigationSplitViewColumnWidth(min: 360, ideal: 440, max: 560)
        } detail: {
            if let key = state.selectedKey {
                KeyDetailView(key: key)
            } else {
                EmptyKeysView()
            }
        }
        .searchable(text: $state.query, prompt: "Nome, provedor ou dica")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    state.reload()
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .disabled(state.isLoading)
                Button {
                    state.refreshCredits()
                } label: {
                    Label("Sondar créditos", systemImage: "dollarsign.circle")
                }
                .disabled(state.isRefreshingCredits)
                Button {
                    state.editorName = state.selectedName ?? ""
                    state.editorValue = ""
                    state.isEditorPresented = true
                } label: {
                    Label("Nova chave", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $state.isEditorPresented) {
            KeyEditorSheet()
                .environmentObject(state)
        }
    }
}

struct StoreStatusPanel: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(state.mongoOK ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(state.mongoOK ? "Mongo no ar" : "Mongo off")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            if let store = state.store {
                Text(store.mongodbDB)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(store.mongodbURI)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            Text("\(state.stats.configured) no cofre · \(state.stats.withCredit) com saldo")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatsBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            StatChip(title: "No cofre", value: "\(state.stats.configured)")
            StatChip(title: "Faltando", value: "\(state.stats.missing)")
            StatChip(title: "Com saldo", value: "\(state.stats.withCredit)")
            Spacer()
            if state.isLoading || state.isRefreshingCredits {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct StatChip: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospaced().weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct KeysListView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        List(selection: $state.selectedName) {
            ForEach(state.visibleKeys) { key in
                KeyRow(key: key)
                    .tag(key.name)
            }
        }
        .listStyle(.inset)
        .overlay {
            if state.isLoading {
                ProgressView("Lendo o cofre…")
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.visibleKeys.isEmpty {
                EmptyKeysView()
            }
        }
    }
}

struct KeyRow: View {
    var key: KeyRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(key.label)
                    .font(.body.weight(.medium))
                Text(key.name)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if key.configured {
                CreditBadge(credit: key.credit)
                Text(key.masked.isEmpty ? "no cofre" : key.masked)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                Text("faltando")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreditBadge: View {
    var credit: CreditSnapshot?

    var body: some View {
        let text = credit?.label.isEmpty == false ? (credit?.label ?? "—") : "—"
        let color: Color = {
            guard let credit else { return .secondary }
            if credit.ok { return .green }
            if credit.status == "unsupported" { return .secondary }
            if credit.status == "missing_key" { return .orange }
            return .red
        }()
        Text(text)
            .font(.caption.monospaced().weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct KeyDetailView: View {
    @EnvironmentObject private var state: AppState
    var key: KeyRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(key.label)
                        .font(.largeTitle.weight(.semibold))
                    Text(key.name)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                    Text(key.hint)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 10) {
                    Label(key.configured ? "No cofre" : "Ainda não",
                          systemImage: key.configured ? "checkmark.seal.fill" : "circle.dotted")
                    Label(key.categoryLabel, systemImage: "folder")
                    if !key.source.isEmpty {
                        Label(key.source, systemImage: "cylinder.split.1x2")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                GroupBox("Valor") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(key.configured ? key.masked : "Nada gravado.")
                            .font(.title3.monospaced())
                        Text("O trecho do meio some. Copiar o valor completo daqui não dá — e é assim que tem que ser.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Crédito") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let credit = key.credit {
                            HStack {
                                CreditBadge(credit: credit)
                                Text(credit.detail)
                                    .foregroundStyle(.secondary)
                            }
                            if let error = credit.error, !error.isEmpty, !credit.ok {
                                Text(error)
                                    .font(.callout)
                            }
                        } else if key.configured {
                            Text("Este provedor não publica saldo por API. A chave está no cofre; o número mora no console deles.")
                        } else {
                            Text("Sem chave, não tem o que consultar.")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Button("Atualizar esta chave") {
                        state.editorName = key.name
                        state.editorValue = ""
                        state.isEditorPresented = true
                    }
                    if key.configured {
                        Button("Apagar", role: .destructive) {
                            state.deleteSelected()
                        }
                    }
                    Spacer()
                    Button("Sondar créditos") { state.refreshCredits() }
                }
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }
}

struct EmptyKeysView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nenhuma chave neste recorte")
                .font(.title2.weight(.semibold))
            Text("O cofre é o mesmo Mongo do QClaw. Cole a primeira chave e o Cursor, o HeyGen e o restante dos MCPs passam a enxergar.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420, alignment: .leading)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct KeyEditorSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gravar chave")
                .font(.title2.weight(.semibold))
            Text("O nome é a variável (OPENAI_API_KEY). O valor some atrás de pontinhos assim que entrar no Mongo.")
                .foregroundStyle(.secondary)
            TextField("Nome da variável", text: $state.editorName)
                .textFieldStyle(.roundedBorder)
            SecureField("Valor", text: $state.editorValue)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Gravar") {
                    state.saveEditor()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(state.editorName.trimmingCharacters(in: .whitespaces).isEmpty
                          || state.editorValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
