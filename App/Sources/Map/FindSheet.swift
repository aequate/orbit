import SwiftUI
import OrbitKit

/// Search, or browse every idea grouped by area. Also the accessible way into the map.
struct FindSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let choose: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ForEach(model.atlas.clusters) { cluster in
                        Section {
                            ForEach(model.atlas.topics(in: cluster.id)) { topic in
                                row(topic)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Circle().fill(Theme.hue(cluster.hue)).frame(width: 8, height: 8)
                                Text(cluster.name)
                            }
                        }
                    }
                } else {
                    let results = model.atlas.search(query)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(results) { topic in
                            row(topic)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Find an idea")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search ideas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func row(_ topic: Topic) -> some View {
        Button {
            dismiss()
            choose(topic.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(model.isUnderstood(topic.id) ? model.atlas.hue(of: topic.id) : Color.clear)
                    .overlay(Circle().stroke(model.atlas.hue(of: topic.id), lineWidth: 2))
                    .frame(width: 12, height: 12)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                    Text(topic.title)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(topic.summary)
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 2)
        }
        .listRowBackground(Theme.surface)
        .accessibilityHint(model.isUnderstood(topic.id) ? "Understood. Shows it on the map." : "Shows it on the map.")
    }
}
