import SwiftUI
import AppKit

// MARK: - Continuity Notification Banner (tvOS-style top-right toast)
struct ContinuityNotificationBanner: View {
    @Environment(LauncherViewModel.self) var vm
    
    var body: some View {
        VStack {
            if let text = vm.continuityNotificationText {
                HStack(spacing: 12) {
                    Image(systemName: vm.continuityNotificationIcon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        if let sub = vm.continuityNotificationSubtext {
                            Text(sub)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 24)
                .padding(.trailing, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: vm.continuityNotificationText)
    }
}

// MARK: - iPhone Keyboard Continuity View (Mockup)
struct IPhoneKeyboardContinuityView: View {
    @Environment(LauncherViewModel.self) var vm
    
    var body: some View {
        VStack(spacing: 16) {
            // iPhone Mockup Frame
            VStack {
                // Dynamic Island
                Capsule()
                    .fill(Color.black)
                    .frame(width: 80, height: 20)
                    .padding(.top, 12)
                
                Spacer()
                
                // iPhone Screen Content
                VStack(spacing: 14) {
                    Image(systemName: "keyboard.iphone")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text("Apple TV Keyboard")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Characters sync instantly to MacLauncher.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // Live Sync Text Area
                    VStack(alignment: .leading, spacing: 4) {
                        Text("INPUT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text(vm.virtualKeyboardText.isEmpty ? "Type on controller or keyboard..." : vm.virtualKeyboardText)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(vm.virtualKeyboardText.isEmpty ? .gray : .black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Continuity Status Bar
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Continuity Connected")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .cornerRadius(24)
                .padding(6)
            }
            .frame(width: 220, height: 420)
            .background(Color.black)
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
            
            Text("iPhone Keyboard Sync Active")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Profile Selector & AirPods Continuity Switcher Overlay
struct ProfileSwitcherOverlay: View {
    @Environment(LauncherViewModel.self) var vm
    
    var body: some View {
        ZStack {
            // Dark transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        vm.isProfileSwitcherVisible = false
                    }
                }
            
            // Frosted Profile Box
            VStack(spacing: 24) {
                Text("SWITCH USER PROFILE")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(2)
                
                VStack(spacing: 12) {
                    ForEach(0..<vm.profiles.count, id: \.self) { idx in
                        let profile = vm.profiles[idx]
                        let isFocused = vm.profileFocusedIndex == idx
                        let isCurrent = vm.currentProfileName == profile
                        
                        Button(action: {
                            vm.profileFocusedIndex = idx
                            vm.activateFocused()
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2)
                                
                                Text(profile)
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Spacer()
                                
                                if isCurrent {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                isFocused
                                ? Color.blue
                                : Color.white.opacity(0.08)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .scaleEffect(isFocused ? 1.03 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isFocused)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(width: 320)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .frame(width: 320)
                
                // AirPods section
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE AIRPODS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                    
                    HStack(spacing: 12) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.activeAirPods)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Automatic Ear Detection Enabled")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(14)
                    .frame(width: 320, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    withAnimation {
                        vm.isProfileSwitcherVisible = false
                    }
                }) {
                    Text("Dismiss")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        }
    }
}
