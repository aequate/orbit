import SwiftUI
import OrbitKit

/// Two ideas side by side, one aspect per row, so differences line up instead of being remembered.
struct CompareScreen: View {
    @Environment(AppModel.self) private var model
    let comparisonID: String

    var body: some View {
        if let comparison = model.atlas.comparison(comparisonID) {
            content(comparison)
        } else {
            ContentUnavailableView("Comparison not found", systemImage: "questionmark.circle")
        }
    }

    private func hue(_ side: Comparison.Side) -> Color {
        side.topic.map { model.atlas.hue(of: $0) } ?? Theme.inkSoft
    }

    private func content(_ comparison: Comparison) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Compare")
                    .font(Theme.label)
                    .foregroundStyle(Theme.inkSoft)
                Text(comparison.title)
                    .font(Theme.title(32))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 10) {
                    sideHeader(comparison.left)
                    sideHeader(comparison.right)
                }

                VStack(spacing: 12) {
                    ForEach(comparison.rows, id: \.aspect) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.aspect)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.inkSoft)
                            HStack(alignment: .top, spacing: 10) {
                                cell(row.left, hue: hue(comparison.left))
                                cell(row.right, hue: hue(comparison.right))
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Words.join([row.aspect, ". ", comparison.left.name, ": ", row.left, ". ", comparison.right.name, ": ", row.right]))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("The takeaway")
                    Text(comparison.takeaway)
                        .font(Theme.reading)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .surface()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 12)
        }
        .background(Theme.paper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sideHeader(_ side: Comparison.Side) -> some View {
        let colour = hue(side)
        return Group {
            if let id = side.topic {
                Button {
                    model.open(.topic(id))
                } label: {
                    sideLabel(side.name, colour: colour, linked: true)
                }
                .buttonStyle(.plain)
            } else {
                sideLabel(side.name, colour: colour, linked: false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func sideLabel(_ name: String, colour: Color, linked: Bool) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.paper)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if linked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.paper.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 8)
        .background(colour, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private func cell(_ text: String, hue: Color) -> some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(hue).frame(width: 4).padding(.vertical, 10)
            }
    }
}
