import Foundation

struct LauncherSection: Identifiable, Codable, Equatable {
    var id: UUID
    var label: String
    var type: ItemType
    var items: [LauncherItem]

    init(id: UUID = UUID(), label: String, type: ItemType, items: [LauncherItem] = []) {
        self.id = id
        self.label = label
        self.type = type
        self.items = items
    }
}
