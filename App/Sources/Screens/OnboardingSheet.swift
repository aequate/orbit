import SwiftUI
import OrbitKit

/// One question on first launch, which sets up Orbit for how you think.
struct OnboardingSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Welcome to Orbit")
                    .font(Theme.title(34))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 28)
                Text("Orbit lays ideas out as a map you can turn, open and build step by step, so you can see how they connect instead of holding them in your head.")
                    .font(Theme.reading)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Do you find it hard to picture things in your mind?")
                        .font(Theme.title(22))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    choice("Yes, often", detail: "Diagrams first, every step kept on screen.", aphantasia: true)
                    choice("Sometimes", detail: "Same extra support. You can switch it off later.", aphantasia: true)
                    choice("No, not really", detail: "Start with reading, diagrams one tap away.", aphantasia: false)
                }

                Text("You can change this any time under You.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .background(Theme.paper)
    }

    private func choice(_ title: String, detail: String, aphantasia: Bool) -> some View {
        Button {
            model.update { state in
                state.settings.aphantasiaMode = aphantasia
                state.onboarded = true
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .surface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
