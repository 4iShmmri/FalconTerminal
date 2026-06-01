import SwiftUI
import UniformTypeIdentifiers

/// The top, browser-style tab strip with create / rename / reorder / pin /
/// color / close affordances.
struct TabBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let theme = appState.theme
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(appState.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabChip(
                            tab: tab,
                            index: index,
                            isActive: tab.id == appState.activeTabID
                        )
                    }
                }
                .padding(.horizontal, 6)
            }

            newTabMenu(theme: theme)
                .padding(.trailing, 6)
        }
        .frame(height: 26)
        .background(Color(theme.background).brightness(theme.isDark ? 0.05 : -0.05))
    }

    private func newTabMenu(theme: Theme) -> some View {
        Menu {
            Button("New Tab") { appState.newTab() }
            if !appState.profiles.isEmpty {
                Divider()
                ForEach(appState.profiles) { profile in
                    Button("New \(profile.name) Tab") { appState.newTab(profile: profile) }
                }
            }
            Divider()
            Button(appState.showSSHSidebar ? "Hide SSH Sidebar" : "Show SSH Sidebar") {
                appState.showSSHSidebar.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 20, height: 18)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 24)
        .foregroundStyle(Color(theme.foreground).opacity(0.7))
        .help("New tab")
    }
}

/// A single tab in the strip.
private struct TabChip: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var tab: TerminalTab
    let index: Int
    let isActive: Bool

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draftName = ""

    private let palette: [String] = ["#E5484D", "#E2B33E", "#46A758", "#4C8DFF", "#A66BFF", "#3DC7C7"]

    var body: some View {
        let theme = appState.theme
        HStack(spacing: 5) {
            if let hex = tab.colorHex {
                Circle().fill(Color(hex: hex)).frame(width: 6, height: 6)
            }
            if tab.pinned {
                Image(systemName: "pin.fill").font(.system(size: 8))
            }
            nameView(theme: theme)
            if isHovering && !tab.pinned {
                Button {
                    appState.closeTab(tab)
                } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(theme.foreground).opacity(isActive ? 0.16 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(isActive ? Color(theme.foreground).opacity(0.22) : Color.clear, lineWidth: 1)
        )
        .foregroundStyle(Color(theme.foreground).opacity(isActive ? 1 : 0.6))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            if isActive { beginEditing() } else { appState.selectTab(tab) }
        }
        .onTapGesture(count: 2) { beginEditing() }
        .contextMenu { contextMenu() }
        .draggable(String(index))
        .dropDestination(for: String.self) { items, _ in
            guard let str = items.first, let from = Int(str),
                  from != index, from < appState.tabs.count else { return false }
            let dest = index > from ? index + 1 : index
            appState.moveTab(from: IndexSet(integer: from), to: dest)
            return true
        }
        .help(tab.displayName)
    }

    @ViewBuilder
    private func nameView(theme: Theme) -> some View {
        if isEditing {
            TextField("Name", text: $draftName, onCommit: commitEditing)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(minWidth: 36, maxWidth: 130)
                .onExitCommand { isEditing = false }
        } else {
            Text(tab.displayName)
                .lineLimit(1)
                .font(.system(size: 11, weight: isActive ? .medium : .regular))
        }
    }

    @ViewBuilder
    private func contextMenu() -> some View {
        Button("Rename") { beginEditing() }
        Button("Duplicate") { appState.duplicateActiveTab() }
        Button(tab.pinned ? "Unpin" : "Pin") { tab.pinned.toggle() }
        Menu("Color") {
            Button("None") { tab.colorHex = nil }
            ForEach(palette, id: \.self) { hex in
                Button { tab.colorHex = hex } label: {
                    Label(hex, systemImage: "circle.fill")
                }
            }
        }
        Divider()
        Button("Close") { appState.closeTab(tab) }
    }

    private func beginEditing() {
        draftName = tab.customName ?? tab.displayName
        isEditing = true
    }

    private func commitEditing() {
        tab.customName = draftName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : draftName
        isEditing = false
    }
}
