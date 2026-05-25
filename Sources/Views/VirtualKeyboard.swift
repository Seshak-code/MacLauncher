import SwiftUI

struct VirtualKeyboard: View {
    @Environment(LauncherViewModel.self) var vm

    var body: some View {
        VStack(spacing: 20) {
            // Header / Title & Current Text Input display
            VStack(spacing: 8) {
                Text(vm.keyboardPrompt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1.0)
                
                // Frosted Text Input Preview
                HStack {
                    Text(vm.virtualKeyboardText.isEmpty ? "Start typing..." : vm.virtualKeyboardText)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(vm.virtualKeyboardText.isEmpty ? .white.opacity(0.3) : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                    
                    Spacer()
                }
                .frame(maxWidth: 600)
                .background(.white.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }
            .padding(.bottom, 10)

            // Grid of Keys
            VStack(spacing: 12) {
                ForEach(0..<vm.keyboardLayout.count, id: \.self) { rIndex in
                    HStack(spacing: 10) {
                        let rowKeys = vm.keyboardLayout[rIndex]
                        ForEach(0..<rowKeys.count, id: \.self) { cIndex in
                            let key = rowKeys[cIndex]
                            let isKeyFocused = (vm.keyboardFocusedRow == rIndex && vm.keyboardFocusedCol == cIndex)
                            
                            KeyboardKeyView(
                                label: key,
                                isFocused: isKeyFocused,
                                isSpecialKey: isSpecialKey(key)
                            )
                            .onTapGesture {
                                vm.keyboardFocusedRow = rIndex
                                vm.keyboardFocusedCol = cIndex
                                vm.activateFocused()
                            }
                        }
                    }
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1.5)
        )
        .frame(maxWidth: 800)
    }

    private func isSpecialKey(_ key: String) -> Bool {
        return ["Space", "Backspace", "Clear", "Cancel", "Done"].contains(key)
    }
}

struct KeyboardKeyView: View {
    let label: String
    let isFocused: Bool
    let isSpecialKey: Bool

    var body: some View {
        Text(label)
            .font(.system(size: isSpecialKey ? 14 : 18, weight: isFocused ? .bold : .medium))
            .foregroundStyle(isFocused ? .black : .white.opacity(0.9))
            .frame(
                width: isSpecialKey ? (label == "Space" ? 110 : 85) : 40,
                height: 44
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused ? .white : .white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? .clear : .white.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isFocused ? 1.15 : 1.0)
            .shadow(color: isFocused ? .white.opacity(0.3) : .clear, radius: 10, x: 0, y: 4)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isFocused)
    }
}
