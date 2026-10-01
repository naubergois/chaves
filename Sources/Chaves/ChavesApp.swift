import AppKit
import SwiftUI

/// Um binário, dois modos: janela do macOS ou servidor MCP em stdio.
@main
enum Launcher {
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.contains("--mcp") || arguments.contains("mcp") {
            MCPServer().run()
        } else if arguments.contains("--help") || arguments.contains("-h") {
            print("""
            Chaves

            Uso:
              Chaves            abre a janela do macOS
              Chaves --mcp      inicia o servidor MCP (JSON-RPC em stdio)

            O cofre é o mesmo Mongo env_keys do QClaw. Valores completos
            nunca saem na lista nem nas ferramentas MCP.
            """)
        } else {
            ChavesApp.main()
        }
    }
}

struct ChavesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Chaves") {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear { state.bootstrap() }
        }
        .defaultSize(width: 1120, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Cofre") {
                Button("Atualizar lista") { state.reload() }
                    .keyboardShortcut("r", modifiers: [.command])
                Button("Sondar créditos") { state.refreshCredits() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Nova chave") { state.isEditorPresented = true }
                    .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
