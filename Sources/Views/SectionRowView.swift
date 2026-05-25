import SwiftUI

struct SectionRowView: View {
    let section: LauncherSection
    let sectionIndex: Int
    let focusedPosition: FocusPosition

    @Environment(LauncherViewModel.self) var vm

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with line separator
            HStack(spacing: 16) {
                Text(section.label)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
            }
            .padding(.horizontal, 4)

            // Horizontal tile list
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 24) {
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, item in
                            let isTileFocused = (focusedPosition.sectionIndex == sectionIndex && focusedPosition.itemIndex == idx)
                            
                            TileView(
                                item: item,
                                position: FocusPosition(sectionIndex: sectionIndex, itemIndex: idx),
                                isFocused: isTileFocused
                            )
                            .id(item.id)
                        }
                        
                        // Add shortcut button
                        let isAddFocused = (focusedPosition.sectionIndex == sectionIndex && focusedPosition.itemIndex == section.items.count)
                        AddTileView(
                            sectionID: section.id,
                            position: FocusPosition(sectionIndex: sectionIndex, itemIndex: section.items.count),
                            isFocused: isAddFocused
                        )
                        .id("add-tile-\(section.id)")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 6)
                    
                    // Auto scroll follow focus
                    .onChange(of: focusedPosition) { _, pos in
                        if pos.sectionIndex == sectionIndex {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                if pos.itemIndex < section.items.count {
                                    proxy.scrollTo(section.items[pos.itemIndex].id, anchor: .center)
                                } else if pos.itemIndex == section.items.count {
                                    proxy.scrollTo("add-tile-\(section.id)", anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
