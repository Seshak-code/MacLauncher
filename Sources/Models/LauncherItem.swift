import Foundation

enum ItemType: String, Codable {
    case app, website, game
}

struct LauncherItem: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var iconEmoji: String          // fallback emoji icon
    var iconBundleID: String?      // if set, load app icon via NSWorkspace
    var accentHex: String          // e.g. "#1E7CF0"
    var url: String                // app bundle URL path or website URL string
    var itemType: ItemType
    var subtitle: String?

    init(id: UUID = UUID(), name: String, iconEmoji: String = "🌐", iconBundleID: String? = nil, accentHex: String = "#1E7CF0", url: String, itemType: ItemType, subtitle: String? = nil) {
        self.id = id
        self.name = name
        self.iconEmoji = iconEmoji
        self.iconBundleID = iconBundleID
        self.accentHex = accentHex
        self.url = url
        self.itemType = itemType
        self.subtitle = subtitle
    }
}
