import SwiftUI
import AppKit

struct AppSwitcherView: View {
    @Environment(LauncherViewModel.self) var vm

    var body: some View {
        ZStack {
            // Blurred background dimming
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 8) {
                    Text("App Switcher")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(.white.opacity(0.4))
                        .textCase(.uppercase)
                    
                    Text("Active Applications")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }

                if vm.appSwitcherItems.isEmpty {
                    VStack(spacing: 12) {
                        Text("📭")
                            .font(.system(size: 48))
                        Text("No applications available")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(height: 200)
                } else {
                    // Horizontal list of running & launcher apps
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 28) {
                                ForEach(Array(vm.appSwitcherItems.enumerated()), id: \.element.id) { idx, item in
                                    let isFocused = vm.appSwitcherFocusedIndex == idx
                                    
                                    AppSwitcherCard(
                                        item: item,
                                        isFocused: isFocused
                                    )
                                    .id(item.id)
                                    .onTapGesture {
                                        vm.appSwitcherFocusedIndex = idx
                                        vm.activateAppSwitcherItem(at: idx)
                                    }
                                    .contextMenu {
                                        if item.isRunning {
                                            Button(role: .destructive) {
                                                vm.terminateAppInSwitcher(at: idx)
                                            } label: {
                                                Label("Force Quit", systemImage: "xmark.circle")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 80)
                            .padding(.vertical, 20)
                        }
                        .onChange(of: vm.appSwitcherFocusedIndex) { _, idx in
                            if idx < vm.appSwitcherItems.count {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(vm.appSwitcherItems[idx].id, anchor: .center)
                                }
                            }
                        }
                    }
                    
                    // Interaction Hints
                    HStack(spacing: 24) {
                        InstructionHint(key: "A / Return", action: "Switch/Open")
                        InstructionHint(key: "B / Delete", action: "Force Quit (If Active)")
                        InstructionHint(key: "ESC", action: "Back")
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

struct AppSwitcherCard: View {
    let item: AppSwitcherItem
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Frosted card base
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isFocused ? .white.opacity(0.18) : .white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(isFocused ? .white.opacity(0.5) : .white.opacity(0.1), lineWidth: isFocused ? 2 : 1)
                    )
                    .shadow(color: isFocused ? .white.opacity(0.15) : .clear, radius: 25, x: 0, y: 12)
                
                // App Icon or Emoji
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .cornerRadius(14)
                } else if let emoji = item.iconEmoji {
                    Text(emoji)
                        .font(.system(size: 48))
                } else {
                    Text("🔳")
                        .font(.system(size: 48))
                }
                
                // Active/Inactive status badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(item.isRunning ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 10, height: 10)
                            .padding(10)
                    }
                }
            }
            .frame(width: 140, height: 140)
            .scaleEffect(isFocused ? 1.12 : 1.0)
            .opacity(item.isRunning ? 1.0 : 0.6)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isFocused)

            // App Label
            Text(item.name)
                .font(.system(size: 13, weight: isFocused ? .bold : .medium))
                .foregroundStyle(isFocused ? .white : .white.opacity(0.6))
                .lineLimit(1)
                .frame(maxWidth: 130)
        }
        .frame(width: 140)
    }
}

struct InstructionHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.15))
                .cornerRadius(6)
                .foregroundStyle(.white)
            
            Text(action)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
