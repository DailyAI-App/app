import SwiftUI

struct StudyPresenceView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    @EnvironmentObject private var motion: HeadphoneMotionService
    @State private var isRunning = false
    @State private var stats: StudyPresenceStats?
    @State private var lastSentAt: Date?
    @State private var error: String?
    @State private var sendTimer: Timer?

    private var client: APIClient { APIClient(baseURL: settings.baseURL, apiKey: settings.apiKey) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(eyebrow: "STUDY PRESENCE", title: "학습 감지", subtitle: "AirPods 착용과 머리 움직임으로 지금 학습 중인지 판단해요")
                    if let error { Text(error).foregroundStyle(Color.brandDanger).font(.footnote) }

                    livePresenceCard
                    statusAndStatsGrid
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color.pageBackground)
            .navigationTitle("학습 감지")
            .task { await refreshStats() }
        }
    }

    private var livePresenceCard: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeading(eyebrow: "REAL-TIME", title: motion.isStudying ? "학습 중으로 감지됨" : "학습 중 아님")

                HStack(spacing: 10) {
                    Circle()
                        .fill(motion.isAvailable ? Color.brandGood : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(motion.isAvailable ? "AirPods 연결됨" : "AirPods 연결 대기")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Text(isRunning ? "10초마다 기록이 자동 저장돼요" : "측정을 시작하면 실시간으로 학습 중 여부를 확인할 수 있어요")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Button {
                    isRunning ? stopSession() : startSession()
                } label: {
                    Label(isRunning ? "측정 중지" : "측정 시작", systemImage: isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.primary(tint: isRunning ? Color.brandDanger : .brand))
                .disabled(!motion.isAvailable)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .stroke(Color.brand.opacity(0.10), lineWidth: 14)
                    .frame(width: 176, height: 176)
                Circle()
                    .trim(from: 0, to: min(max(motion.presenceScore / 10, 0), 1))
                    .stroke(
                        LinearGradient(colors: [Color.brand, Color(red: 0x8f / 255, green: 0xa7 / 255, blue: 0xef / 255)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 176, height: 176)
                    .animation(.spring(response: 0.5), value: motion.presenceScore)

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", motion.presenceScore))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("/ 10")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Circle()
                    .fill(Color.brand)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(color: Color.brand.opacity(0.35), radius: 6)
                    .offset(y: -88)
                    .rotationEffect(.degrees(Double(min(max(motion.presenceScore / 10, 0), 1)) * 360))
                    .animation(.spring(response: 0.5), value: motion.presenceScore)
            }
            .frame(width: 210)
        }
        .padding(26)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.primary.opacity(0.055), lineWidth: 1))
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }

    private var statusAndStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: "TODAY")
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }
                Text(stats?.average.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("오늘 평균 학습 감지 점수")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(minHeight: 150)
            .background(Color.bentoLavender, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: "RECORD")
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(Color.brand)
                }
                Text(stats.map { "\($0.count)" } ?? "0")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("누적 측정 기록")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(minHeight: 150)
            .background(Color.bentoBlue, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: "ALERT")
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Text(stats.map { "\($0.abnormalCount)" } ?? "0")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("학습 이탈 감지 횟수")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(minHeight: 150)
            .background(Color.bentoYellow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: "SYNC")
                    Spacer()
                    Image(systemName: lastSentAt == nil ? "icloud.slash" : "checkmark.icloud.fill")
                        .foregroundStyle(lastSentAt == nil ? .secondary : Color.brandGood)
                }
                Text(lastSentAt == nil ? "대기 중" : "저장됨")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(lastSentAt?.formatted(date: .omitted, time: .shortened) ?? "측정 시작 후 기록돼요")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(minHeight: 150)
            .background(Color.bentoMint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func startSession() {
        motion.start()
        isRunning = true
        sendTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { await sendScore() }
        }
    }

    private func stopSession() {
        motion.stop()
        isRunning = false
        sendTimer?.invalidate()
        sendTimer = nil
    }

    private func sendScore() async {
        do {
            stats = try await client.postStudyPresenceScore(motion.presenceScore, source: "dailyai-app")
            lastSentAt = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func refreshStats() async {
        stats = try? await client.fetchStudyPresence()
    }
}
