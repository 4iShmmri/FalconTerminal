import SwiftUI

/// A slash-command launcher. Opens with ⌘K pre-filled with `/`; the user types
/// a command like `/new aaa` and presses Return. It never interferes with the
/// terminal, which keeps `/` as an ordinary character.
struct CommandPaletteView: View {
    @EnvironmentObject private var appState: AppState
    @State private var text = "/"
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let theme = appState.theme
        VStack(spacing: 0) {
            field(theme: theme)
            if !filtered.isEmpty {
                Divider().overlay(Color(theme.foreground).opacity(0.1))
                list(theme: theme)
            }
        }
        .frame(width: 520)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(theme.background).opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(theme.foreground).opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        .padding(20)
        .frame(width: 560)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fieldFocused = true }
        }
    }

    private func field(theme: Theme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(Color(theme.foreground).opacity(0.5))
            TextField("Type a command…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(Color(theme.foreground))
                .focused($fieldFocused)
                .onSubmit(run)
                .onExitCommand(perform: close)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private func list(theme: Theme) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(filtered) { command in
                    Button { apply(command) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(command.usage)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                Text(command.summary)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(theme.foreground).opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(theme.foreground))
                }
            }
        }
        .frame(maxHeight: 260)
    }

    /// Commands matching the first typed token.
    private var filtered: [PaletteCommand] {
        let token = currentToken
        guard !token.isEmpty else { return PaletteCommand.all }
        return PaletteCommand.all.filter { $0.matches(token) }
    }

    private var currentToken: String {
        var s = text
        if s.hasPrefix("/") { s.removeFirst() }
        return String(s.split(separator: " ").first ?? "")
    }

    private func apply(_ command: PaletteCommand) {
        if command.takesArgument {
            // Keep any argument the user already typed.
            let existingArg = text.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
            text = "/\(command.name) \(existingArg)"
            fieldFocused = true
        } else {
            text = "/\(command.name)"
            run()
        }
    }

    private func run() {
        appState.runCommand(text)
        close()
    }

    private func close() {
        appState.showCommandPalette = false
    }
}
