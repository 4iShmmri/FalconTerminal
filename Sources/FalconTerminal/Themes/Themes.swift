import Foundation

/// Built-in color schemes. `falconDark` is the default pure-black theme.
enum Themes {
    static let all: [Theme] = [
        falconDark, dracula, nord, tokyoNight, solarizedDark, solarizedLight
    ]

    static func named(_ name: String) -> Theme {
        all.first { $0.name == name } ?? falconDark
    }

    // MARK: - Falcon Dark (default, pure black)

    static let falconDark = Theme(
        name: "Falcon Dark",
        isDark: true,
        background: RGBColor(hex: "#000000"),
        foreground: RGBColor(hex: "#EAEAEA"),
        cursor: RGBColor(hex: "#FFFFFF"),
        cursorText: RGBColor(hex: "#000000"),
        selection: RGBColor(hex: "#33373D"),
        palette: [
            RGBColor(hex: "#1A1A1A"), RGBColor(hex: "#E5484D"), RGBColor(hex: "#46A758"), RGBColor(hex: "#E2B33E"),
            RGBColor(hex: "#4C8DFF"), RGBColor(hex: "#A66BFF"), RGBColor(hex: "#3DC7C7"), RGBColor(hex: "#D6D6D6"),
            RGBColor(hex: "#6E6E6E"), RGBColor(hex: "#FF6369"), RGBColor(hex: "#5BD675"), RGBColor(hex: "#F5CC5B"),
            RGBColor(hex: "#79A9FF"), RGBColor(hex: "#C08CFF"), RGBColor(hex: "#5FE3E3"), RGBColor(hex: "#FFFFFF")
        ]
    )

    // MARK: - Dracula

    static let dracula = Theme(
        name: "Dracula",
        isDark: true,
        background: RGBColor(hex: "#282A36"),
        foreground: RGBColor(hex: "#F8F8F2"),
        cursor: RGBColor(hex: "#F8F8F2"),
        cursorText: RGBColor(hex: "#282A36"),
        selection: RGBColor(hex: "#44475A"),
        palette: [
            RGBColor(hex: "#21222C"), RGBColor(hex: "#FF5555"), RGBColor(hex: "#50FA7B"), RGBColor(hex: "#F1FA8C"),
            RGBColor(hex: "#BD93F9"), RGBColor(hex: "#FF79C6"), RGBColor(hex: "#8BE9FD"), RGBColor(hex: "#F8F8F2"),
            RGBColor(hex: "#6272A4"), RGBColor(hex: "#FF6E6E"), RGBColor(hex: "#69FF94"), RGBColor(hex: "#FFFFA5"),
            RGBColor(hex: "#D6ACFF"), RGBColor(hex: "#FF92DF"), RGBColor(hex: "#A4FFFF"), RGBColor(hex: "#FFFFFF")
        ]
    )

    // MARK: - Nord

    static let nord = Theme(
        name: "Nord",
        isDark: true,
        background: RGBColor(hex: "#2E3440"),
        foreground: RGBColor(hex: "#D8DEE9"),
        cursor: RGBColor(hex: "#D8DEE9"),
        cursorText: RGBColor(hex: "#2E3440"),
        selection: RGBColor(hex: "#434C5E"),
        palette: [
            RGBColor(hex: "#3B4252"), RGBColor(hex: "#BF616A"), RGBColor(hex: "#A3BE8C"), RGBColor(hex: "#EBCB8B"),
            RGBColor(hex: "#81A1C1"), RGBColor(hex: "#B48EAD"), RGBColor(hex: "#88C0D0"), RGBColor(hex: "#E5E9F0"),
            RGBColor(hex: "#4C566A"), RGBColor(hex: "#BF616A"), RGBColor(hex: "#A3BE8C"), RGBColor(hex: "#EBCB8B"),
            RGBColor(hex: "#81A1C1"), RGBColor(hex: "#B48EAD"), RGBColor(hex: "#8FBCBB"), RGBColor(hex: "#ECEFF4")
        ]
    )

    // MARK: - Tokyo Night

    static let tokyoNight = Theme(
        name: "Tokyo Night",
        isDark: true,
        background: RGBColor(hex: "#1A1B26"),
        foreground: RGBColor(hex: "#C0CAF5"),
        cursor: RGBColor(hex: "#C0CAF5"),
        cursorText: RGBColor(hex: "#1A1B26"),
        selection: RGBColor(hex: "#33467C"),
        palette: [
            RGBColor(hex: "#15161E"), RGBColor(hex: "#F7768E"), RGBColor(hex: "#9ECE6A"), RGBColor(hex: "#E0AF68"),
            RGBColor(hex: "#7AA2F7"), RGBColor(hex: "#BB9AF7"), RGBColor(hex: "#7DCFFF"), RGBColor(hex: "#A9B1D6"),
            RGBColor(hex: "#414868"), RGBColor(hex: "#F7768E"), RGBColor(hex: "#9ECE6A"), RGBColor(hex: "#E0AF68"),
            RGBColor(hex: "#7AA2F7"), RGBColor(hex: "#BB9AF7"), RGBColor(hex: "#7DCFFF"), RGBColor(hex: "#C0CAF5")
        ]
    )

    // MARK: - Solarized Dark

    static let solarizedDark = Theme(
        name: "Solarized Dark",
        isDark: true,
        background: RGBColor(hex: "#002B36"),
        foreground: RGBColor(hex: "#839496"),
        cursor: RGBColor(hex: "#93A1A1"),
        cursorText: RGBColor(hex: "#002B36"),
        selection: RGBColor(hex: "#073642"),
        palette: [
            RGBColor(hex: "#073642"), RGBColor(hex: "#DC322F"), RGBColor(hex: "#859900"), RGBColor(hex: "#B58900"),
            RGBColor(hex: "#268BD2"), RGBColor(hex: "#D33682"), RGBColor(hex: "#2AA198"), RGBColor(hex: "#EEE8D5"),
            RGBColor(hex: "#002B36"), RGBColor(hex: "#CB4B16"), RGBColor(hex: "#586E75"), RGBColor(hex: "#657B83"),
            RGBColor(hex: "#839496"), RGBColor(hex: "#6C71C4"), RGBColor(hex: "#93A1A1"), RGBColor(hex: "#FDF6E3")
        ]
    )

    // MARK: - Solarized Light

    static let solarizedLight = Theme(
        name: "Solarized Light",
        isDark: false,
        background: RGBColor(hex: "#FDF6E3"),
        foreground: RGBColor(hex: "#657B83"),
        cursor: RGBColor(hex: "#586E75"),
        cursorText: RGBColor(hex: "#FDF6E3"),
        selection: RGBColor(hex: "#EEE8D5"),
        palette: [
            RGBColor(hex: "#073642"), RGBColor(hex: "#DC322F"), RGBColor(hex: "#859900"), RGBColor(hex: "#B58900"),
            RGBColor(hex: "#268BD2"), RGBColor(hex: "#D33682"), RGBColor(hex: "#2AA198"), RGBColor(hex: "#EEE8D5"),
            RGBColor(hex: "#002B36"), RGBColor(hex: "#CB4B16"), RGBColor(hex: "#586E75"), RGBColor(hex: "#657B83"),
            RGBColor(hex: "#839496"), RGBColor(hex: "#6C71C4"), RGBColor(hex: "#93A1A1"), RGBColor(hex: "#FDF6E3")
        ]
    )
}
