import SwiftUI
internal import Combine

struct RGB: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
}

struct Category: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var icon: String
    var rgb: RGB
    var color: Color { rgb.color }
}

class CategoryManager: ObservableObject {
    @Published var categories: [Category] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(categories) {
                UserDefaults.standard.set(data, forKey: "userCategories")
            }
        }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "userCategories"),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            self.categories = decoded
        } else {
            self.categories = [
                Category(name: "Deep Work", icon: "brain.head.profile", rgb: RGB(r: 0.75, g: 0.55, b: 0.45)),
                Category(name: "Meeting", icon: "person.2.fill", rgb: RGB(r: 0.85, g: 0.78, b: 0.58)),
                Category(name: "Break", icon: "cup.and.saucer.fill", rgb: RGB(r: 0.35, g: 0.42, b: 0.35)),
                Category(name: "Study", icon: "book.fill", rgb: RGB(r: 0.45, g: 0.50, b: 0.35))
            ]
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case sage, navy, rose, charcoal, sakura
    var id: String { self.rawValue }
    var name: String { self == .sakura ? "Sakura" : self.rawValue.capitalized }
    
    var bg: Color {
        switch self {
        case .sage: return Color(red: 0.18, green: 0.23, blue: 0.18)
        case .navy: return Color(red: 0.08, green: 0.12, blue: 0.18)
        case .rose: return Color(red: 0.24, green: 0.15, blue: 0.18)
        case .charcoal: return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .sakura: return Color(red: 0.96, green: 0.90, blue: 0.92)
        }
    }
    var fieldBg: Color {
        switch self {
        case .sage: return Color(red: 0.15, green: 0.20, blue: 0.15)
        case .navy: return Color(red: 0.06, green: 0.09, blue: 0.14)
        case .rose: return Color(red: 0.20, green: 0.12, blue: 0.15)
        case .charcoal: return Color(red: 0.09, green: 0.09, blue: 0.09)
        case .sakura: return Color(red: 1.0, green: 0.95, blue: 0.96)
        }
    }
    var accent: Color {
        switch self {
        case .sage: return Color(red: 0.85, green: 0.78, blue: 0.58)
        case .navy: return Color(red: 0.65, green: 0.82, blue: 0.95)
        case .rose: return Color(red: 0.88, green: 0.68, blue: 0.72)
        case .charcoal: return Color(red: 0.80, green: 0.80, blue: 0.80)
        case .sakura: return Color(red: 0.85, green: 0.45, blue: 0.55)
        }
    }
    var shadowLight: Color {
        switch self {
        case .sage: return Color(red: 0.22, green: 0.28, blue: 0.22)
        case .navy: return Color(red: 0.10, green: 0.15, blue: 0.22)
        case .rose: return Color(red: 0.28, green: 0.18, blue: 0.22)
        case .charcoal: return Color(red: 0.16, green: 0.16, blue: 0.16)
        case .sakura: return Color(red: 1.0, green: 1.0, blue: 1.0)
        }
    }
    var shadowDark: Color {
        switch self {
        case .sage: return Color(red: 0.12, green: 0.16, blue: 0.12)
        case .navy: return Color(red: 0.05, green: 0.08, blue: 0.12)
        case .rose: return Color(red: 0.18, green: 0.10, blue: 0.13)
        case .charcoal: return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .sakura: return Color(red: 0.85, green: 0.80, blue: 0.82)
        }
    }
    var taskTrack: Color {
        switch self {
        case .sage: return Color(red: 0.25, green: 0.30, blue: 0.25)
        case .navy: return Color(red: 0.12, green: 0.18, blue: 0.28)
        case .rose: return Color(red: 0.32, green: 0.20, blue: 0.25)
        case .charcoal: return Color(red: 0.20, green: 0.20, blue: 0.20)
        case .sakura: return Color(red: 0.92, green: 0.82, blue: 0.85)
        }
    }
    var textForeground: Color {
        switch self {
        case .sakura: return Color(red: 0.4, green: 0.3, blue: 0.35)
        default: return .white
        }
    }
}
