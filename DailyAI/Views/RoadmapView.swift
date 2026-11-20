import SwiftUI

struct RoadmapView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    @State private var roadmaps: [Roadmap] = []
    @State private var company = ""
    @State private var role = ""
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
                        SectionHeading(eyebrow: "새 로드맵", title: "어떤 회사·직무가 목표인가요?")
                        HStack {
                            TextField("회사 이름 (예: 네이버)", text: $company)
                                .textFieldStyle(.roundedBorder)
                            TextField("직업/직무 (예: 백엔드 개발자, 마케터)", text: $role)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(isGenerating ? "생성 중…" : "만들기") { Task { await generate() } }
                            .buttonStyle(.primary(fullWidth: true))
                            .disabled(isGenerating || company.trimmingCharacters(in: .whitespaces).isEmpty || role.trimmingCharacters(in: .whitespaces).isEmpty)
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
                                    HStack(spacing: 4) {
                                        Text(roadmap.company).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
                                        if let role = roadmap.role {
                                            Text("· \(role)").font(.system(size: 13)).foregroundStyle(.secondary)
                                        }
                                    }
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
        let jobRole = role.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !jobRole.isEmpty else { return }
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        do {
            let steps = try await client.generateRoadmapSteps(company: name, role: jobRole)
            roadmaps = try await client.saveRoadmap(company: name, role: jobRole, steps: steps)
            company = ""
            role = ""
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
    @State private var expandedStepId: String?

    init(roadmap: Roadmap, client: APIClient, onUpdated: @escaping ([Roadmap]) -> Void) {
        self.roadmap = roadmap
        self.client = client
        self.onUpdated = onUpdated
        _steps = State(initialValue: roadmap.steps)
    }

    private var progress: Double {
        steps.isEmpty ? 0 : Double(steps.filter(\.done).count) / Double(steps.count)
    }

    // the first not-done step is "current" — like a Duolingo lesson path,
    // it glows; later steps look "not reached yet" but stay toggleable
    // directly (this is a flexible checklist, not a hard-gated course).
    private var currentIndex: Int? {
        steps.firstIndex { !$0.done }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: progress).tint(.brand)
                    Text("\(steps.filter(\.done).count) / \(steps.count) 완료").font(.caption).foregroundStyle(.secondary)
                }
                .cardStyle()

                VStack(spacing: 14) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        // a mild left/right zigzag — roadmap.sh's branching
                        // mind-map feel, approximated without a custom graph layout.
                        HStack(spacing: 0) {
                            if index % 2 != 0 { Spacer(minLength: 24) }
                            stepCard(step, index: index, isCurrent: index == currentIndex)
                            if index % 2 == 0 { Spacer(minLength: 24) }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.pageBackground)
        .navigationTitle(roadmap.role.map { "\(roadmap.company) · \($0)" } ?? roadmap.company)
    }

    @ViewBuilder
    private func stepCard(_ step: RoadmapStep, index: Int, isCurrent: Bool) -> some View {
        let isExpanded = expandedStepId == step.id
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                Button { Task { await toggle(step) } } label: {
                    ZStack {
                        Circle()
                            .fill(step.done || isCurrent ? Color.brand : Color.raisedBackground)
                            .frame(width: 40, height: 40)
                        if step.done {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)").font(.system(size: 14, weight: .bold)).foregroundStyle(isCurrent ? .white : .secondary)
                        }
                    }
                    .scaleEffect(step.done ? 1 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.55), value: step.done)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    Button { Task { await toggle(step) } } label: {
                        HStack {
                            Text(step.title)
                                .font(.system(size: 14, weight: .semibold))
                                .strikethrough(step.done)
                                .foregroundStyle(step.done ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if isCurrent {
                                Text("지금")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.brand, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if let topics = step.topics, !topics.isEmpty {
                        FlowChips(items: topics, label: { $0.done ? "✓ \($0.name)" : $0.name }, isSelected: { $0.done }) { tapped in
                            if let index = topics.firstIndex(where: { $0.name == tapped.name }) {
                                Task { await toggleTopic(step: step, topicIndex: index) }
                            }
                        }
                    }

                    if let detail = step.detail, !detail.isEmpty {
                        Button(isExpanded ? "접기" : "자세히") {
                            expandedStepId = isExpanded ? nil : step.id
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.brand)
                    }
                    if isExpanded, let detail = step.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.raisedBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(14)
        .background(step.done ? Color.brandDim : Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isCurrent ? Color.brand : Color.primary.opacity(0.055), lineWidth: isCurrent ? 2 : 1)
        )
        .opacity(step.done || isCurrent ? 1 : 0.65)
    }

    private func toggle(_ step: RoadmapStep) async {
        guard let updated = try? await client.toggleRoadmapStep(roadmapId: roadmap.id, stepId: step.id) else { return }
        onUpdated(updated)
        if let match = updated.first(where: { $0.id == roadmap.id }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { steps = match.steps }
        }
    }

    private func toggleTopic(step: RoadmapStep, topicIndex: Int) async {
        guard let updated = try? await client.toggleRoadmapTopic(roadmapId: roadmap.id, stepId: step.id, topicIndex: topicIndex) else { return }
        onUpdated(updated)
        if let match = updated.first(where: { $0.id == roadmap.id }) { steps = match.steps }
    }
}
