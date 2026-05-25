import SwiftUI

struct AddItemSheet: View {
    @Environment(LauncherViewModel.self) var vm
    
    @State private var name = ""
    @State private var icon = "🌐"
    @State private var url = ""
    @State private var bundleID = ""
    @State private var accentHex = "#007AFF"
    @State private var itemType: ItemType = .app

    // Preset color codes
    let colorPresets = [
        ("#FF3B30", "Red"),
        ("#FF9500", "Orange"),
        ("#FFCC00", "Yellow"),
        ("#34C759", "Green"),
        ("#00C7BE", "Teal"),
        ("#007AFF", "Blue"),
        ("#5856D6", "Indigo"),
        ("#AF52DE", "Purple"),
        ("#FF2D55", "Pink"),
        ("#8E8E93", "Gray")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    HStack {
                        TextField("Name", text: $name)
                        
                        Button {
                            vm.showKeyboard(initialText: name, prompt: "Enter Name") { text in
                                name = text
                            } onCancel: {}
                        } label: {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Virtual Keyboard")
                    }

                    HStack {
                        TextField("Icon (Emoji)", text: $icon)
                        
                        Button {
                            vm.showKeyboard(initialText: icon, prompt: "Enter Emoji Icon") { text in
                                icon = text
                            } onCancel: {}
                        } label: {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Virtual Keyboard")
                    }

                    HStack {
                        TextField("URL or Local Path", text: $url)
                        
                        Button {
                            vm.showKeyboard(initialText: url, prompt: "Enter URL / Path") { text in
                                url = text
                            } onCancel: {}
                        } label: {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Virtual Keyboard")
                    }
                    
                    HStack {
                        TextField("Bundle ID (Optional for App Icon lookup)", text: $bundleID)
                        
                        Button {
                            vm.showKeyboard(initialText: bundleID, prompt: "Enter Bundle ID") { text in
                                bundleID = text
                            } onCancel: {}
                        } label: {
                            Image(systemName: "keyboard")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Virtual Keyboard")
                    }
                }

                Section("Theme Accent Color") {
                    // Custom Horizontal Swatch selector for gamepad users
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(colorPresets, id: \.0) { hex, label in
                                    let color = Color(hex: hex) ?? .blue
                                    let isSelected = (accentHex.uppercased() == hex.uppercased())
                                    
                                    Circle()
                                        .fill(color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: isSelected ? 2.5 : 0)
                                        )
                                        .scaleEffect(isSelected ? 1.15 : 1.0)
                                        .shadow(radius: isSelected ? 4 : 0)
                                        .onTapGesture {
                                            accentHex = hex
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Custom picker fallback
                        ColorPicker("Custom Accent Color", selection: Binding(
                            get: { Color(hex: accentHex) ?? .blue },
                            set: { accentHex = $0.hexString }
                        ))
                    }
                }

                Section("Category") {
                    Picker("Section Type", selection: $itemType) {
                        Text("Application").tag(ItemType.app)
                        Text("Website").tag(ItemType.website)
                        Text("Game").tag(ItemType.game)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Shortcut Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.isAddingItem = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let finalBundle = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bundleID
                        let newItem = LauncherItem(
                            name: name,
                            iconEmoji: icon,
                            iconBundleID: finalBundle,
                            accentHex: accentHex,
                            url: url,
                            itemType: itemType
                        )
                        
                        // Find matching section by type, or use first section
                        let targetSectionID = vm.addTargetSectionID ?? vm.sections.first(where: { $0.type == itemType })?.id
                        if let sID = targetSectionID {
                            vm.addItem(newItem, toSectionID: sID)
                        }
                        
                        vm.isAddingItem = false
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 480)
        .preferredColorScheme(.dark)
    }
}
