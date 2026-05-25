import SwiftUI

struct TopBarView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var username: String {
        let name = NSFullUserName()
        return name.isEmpty ? NSUserName() : name
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    @Environment(LauncherViewModel.self) var vm

    var body: some View {
        HStack(alignment: .top) {
            // Left Greeting & Profile Indicator
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2.0)
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text(username)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                }
                
                Button(action: {
                    withAnimation {
                        vm.isProfileSwitcherVisible = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.blue)
                        Text(vm.currentProfileName)
                            .font(.system(size: 12, weight: .semibold))
                        Text("•")
                        Image(systemName: "airpodspro")
                        Text(vm.activeAirPods)
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(14)
                    .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            // Right Clock
            VStack(alignment: .trailing, spacing: 6) {
                Text(now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                    .font(.system(size: 72, weight: .ultraLight, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.95))
                    .kerning(-3)

                Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.4))
                    .textCase(.uppercase)
            }
        }
        .onReceive(timer) { newTime in
            self.now = newTime
        }
    }
}
