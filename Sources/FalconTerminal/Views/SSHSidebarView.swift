import SwiftUI

/// Sidebar of saved SSH hosts, grouped by environment, with quick-connect.
struct SSHSidebarView: View {
    @EnvironmentObject private var appState: AppState

    private var groupedHosts: [(group: String, hosts: [SSHHost])] {
        let groups = Dictionary(grouping: appState.sshHosts, by: \.group)
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        let theme = appState.theme
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("SSH Hosts", systemImage: "network")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    appState.showSSHSidebar = false
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .foregroundStyle(Color(theme.foreground))

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedHosts, id: \.group) { section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.group.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(theme.foreground).opacity(0.4))
                                .padding(.horizontal, 12)
                            ForEach(section.hosts) { host in
                                HostRow(host: host)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color(theme.background).brightness(theme.isDark ? 0.03 : -0.03))
    }
}

private struct HostRow: View {
    @EnvironmentObject private var appState: AppState
    let host: SSHHost
    @State private var hovering = false

    var body: some View {
        let theme = appState.theme
        Button {
            appState.connect(to: host)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(host.name)
                    .font(.system(size: 12, weight: .medium))
                Text(host.displayTarget)
                    .font(.system(size: 10))
                    .foregroundStyle(Color(theme.foreground).opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, 12)
            .background(
                Color(theme.foreground).opacity(hovering ? 0.10 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(theme.foreground))
        .onHover { hovering = $0 }
        .help("Connect to \(host.displayTarget)")
    }
}
