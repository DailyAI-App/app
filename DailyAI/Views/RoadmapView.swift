import SwiftUI

struct RoadmapView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    @State private var roadmaps: [Roadmap] = []
    @State private var company = ""
    @State private var isGenerating = false
    @State private var error: String?
    @State private var selected: Roadmap?

    private var client: APIClient { APIClient(baseURL: settings.baseURL, apiKey: settings.apiKey) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(eyebrow: "CAREER GROWTH", title: "나의 로드맵", subtitle: "목표 회사에 필요한 역량을 작은 단계로 나눠요")
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(eyebrow: "새 로드맵", title: "어떤 회사가 목표인가요?")
                        HStack {
                            TextField("회사 이름 (예: 네이버)", text: $company)
                                .textFieldStyle(.roundedBorder)
                            Button(isGenerating ? "생성 중…" : "만들기") { Task { await generate() } }
                                .buttonStyle(.primary)
                                .disabled(isGenerating || company.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .cardStyle()

                    if let error { Text(error).foregroundStyle(Color.brandDanger).font(.footnote) }

                    if roadmaps.isEmpty {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.bentoLavender)
                                Image(systemName: "map")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(Color.brand)
                            }
                            .frame(width: 64, height: 64)
                            Text("아직 만든 로드맵이 없어요")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .cardStyle()
                    }
                    ForEach(roadmaps) { roadmap in
                        let done = roadmap.steps.filter(\.done).count
                        Button {
                            selected = roadmap
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(roadmap.company).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                                    Text("\(done) / \(roadmap.steps.count) 완료").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .cardStyle()
                        .contextMenu {
                            Button("삭제", role: .destructive) { Task { await delete(roadmap) } }
                        }
                    }
                }
                .padding()
            }
            .background(Color.pageBackground)
            .navigationTitle("로드맵")
            .task { await load() }
            .refreshable { await load() }
            .navigationDestination(item: $selected) { roadmap in
                RoadmapDetailView(roadmap: roadmap, client: client, onUpdated: { roadmaps = $0; selected = $0.first { $0.id == roadmap.id } })
            }
        }
    }

    private func load() async {
        do { roadmaps = try await client.fetchRoadmaps() } catch { self.error = error.localizedDescription }
    }

    private func generate() async {
        let name = company.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        do {
            let steps = try await client.generateRoadmapSteps(company: name)
            roadmaps = try await client.saveRoadmap(company: name, steps: steps)
            company = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ roadmap: Roadmap) async {
        do { roadmaps = try await client.deleteRoadmap(id: roadmap.id) } catch { self.error = error.localizedDescription }
    }
}

private struct RoadmapDetailView: View {
    let roadmap: Roadmap
    let client: APIClient
    let onUpdated: ([Roadmap]) -> Void
    @State private var steps: [RoadmapStep]

    init(roadmap: Roadmap, client: APIClient, onUpdated: @escaping ([Roadmap]) -> Void) {
        self.roadmap = roadmap
        self.client = client
        self.onUpdated = onUpdated
        _steps = State(initialValue: roadmap.steps)
    }

    private var progress: Double {
        steps.isEmpty ? 0 : Double(steps.filter(\.done).count) / Double(steps.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: progress).tint(.brand)
                    Text("\(steps.filter(\.done).count) / \(steps.count) 완료").font(.caption).foregroundStyle(.secondary)
                }
                .cardStyle()

                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        Button { Task { await toggle(step) } } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(step.done ? Color.brand : Color.raisedBackground)
                                        .frame(width: 32, height: 32)
                                    if step.done {
                                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                    } else {
                                        Text("\(index + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(.secondary)
                                    }
                                }
                                Text(step.title)
                                    .font(.system(size: 14))
                                    .strikethrough(step.done)
                                    .foregroundStyle(step.done ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if index != steps.count - 1 { Divider().padding(.leading, 46) }
                    }
                }
                .cardStyle()
            }
            .padding()
        }
        .background(Color.pageBackground)
        .navigationTitle(roadmap.company)
    }

    private func toggle(_ step: RoadmapStep) async {
        guard let updated = try? await client.toggleRoadmapStep(roadmapId: roadmap.id, stepId: step.id) else { return }
        onUpdated(updated)
        if let match = updated.first(where: { $0.id == roadmap.id }) { steps = match.steps }
    }
}
