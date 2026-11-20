import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    @EnvironmentObject private var motion: HeadphoneMotionService
    @State private var studyData: StudyData?
    @State private var seconds = 0
    @State private var isRunning = false
    @State private var error: String?
    @State private var timer: Timer?
    @State private var presenceTimer: Timer?
    @State private var collectedScores: [Double] = []

    private var client: APIClient { APIClient(baseURL: settings.baseURL, apiKey: settings.apiKey) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(eyebrow: "TODAY", title: "오늘", subtitle: "집중 시작을 누르면 AirPods가 자동으로 학습 중인지 감지해요")
                    if let error { Text(error).foregroundStyle(Color.brandDanger).font(.footnote) }

                    statsRow
                    focusCard
                    timelineCard
                }
                .padding()
            }
            .background(Color.pageBackground)
            .navigationTitle("오늘")
            .task { await loadStudy() }
        }
    }

    private var statsRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            statTile("이번 주 학습", formatMinutes(studyData?.analytics.totalMinutes ?? 0), "clock.fill", Color.bentoLavender)
            statTile("연속 학습 스트릭", "\(studyData?.analytics.currentStreak ?? 0)일", "flame.fill", Color.bentoYellow)
        }
    }

    private func statTile(_ label: String, _ value: String, _ icon: String, _ background: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.brand)
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(18)
        .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeading(eyebrow: "FOCUS SESSION", title: "오늘의 집중 세션")
                Spacer()
                Text(isRunning ? "집중 중" : "준비됨").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(timerLabel).font(.system(size: 48, weight: .bold, design: .rounded))
            Text(statusCopy).font(.system(size: 13)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(isRunning ? "세션 저장" : "집중 시작") {
                    if isRunning { Task { await finishSession() } } else { startSession() }
                }
                .buttonStyle(.primary)
                if isRunning {
                    Button("타이머 초기화") { seconds = 0 }.buttonStyle(.chip(selected: false))
                }
            }
        }
        .cardStyle()
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeading(eyebrow: "ACTIVITY", title: "오늘의 타임로그")
            TodayTimelineBar(sessions: studyData?.sessions ?? [])
        }
        .cardStyle()
    }

    private var timerLabel: String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var statusCopy: String {
        guard isRunning else { return "타이머를 시작하면 AirPods 착용 여부로 학습 중인지 자동으로 감지해요." }
        guard motion.isAvailable else { return "지금은 한 가지 학습에만 집중해보세요. 25분 뒤 휴식을 권장합니다." }
        return motion.isStudying
            ? "AirPods로 학습 중 감지됨 · \(String(format: "%.1f", motion.presenceScore))/10"
            : "AirPods 연결됨 · 안정적으로 집중해보세요"
    }

    private func startSession() {
        seconds = 0
        collectedScores = []
        isRunning = true
        motion.start()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in seconds += 1 }
        }
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                collectedScores.append(motion.presenceScore)
                _ = try? await client.postStudyPresenceScore(motion.presenceScore, source: "dailyai-app")
            }
        }
    }

    private func finishSession() async {
        isRunning = false
        timer?.invalidate()
        timer = nil
        presenceTimer?.invalidate()
        presenceTimer = nil
        motion.stop()

        let minutes = max(1, Int((Double(seconds) / 60).rounded()))
        let averagePresence = collectedScores.isEmpty ? nil : collectedScores.reduce(0, +) / Double(collectedScores.count)
        do {
            studyData = try await client.saveStudySession(minutes: minutes, focusState: seconds >= 20 * 60 ? "steady" : "short", presenceScore: averagePresence)
            seconds = 0
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadStudy() async {
        studyData = try? await client.fetchStudy()
    }

    private func formatMinutes(_ total: Int) -> String {
        guard total > 0 else { return "0분" }
        let hours = total / 60
        let minutes = total % 60
        if hours == 0 { return "\(minutes)분" }
        if minutes == 0 { return "\(hours)시간" }
        return "\(hours)시간 \(minutes)분"
    }
}
