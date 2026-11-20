import SwiftUI

// "열품타"-style day bar: one colored block per today's study session,
// positioned by time of day. Color reflects the AirPods-detected presence
// score for that session (nil when no AirPods signal was captured).
struct TodayTimelineBar: View {
    let sessions: [StudySession]

    private let hourMarks = [0, 6, 12, 18, 24]

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func parseDate(_ iso: String) -> Date? {
        Self.isoFormatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    private func minutesFromMidnight(_ date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    private func color(for score: Double?) -> Color {
        guard let score else { return Color.secondary.opacity(0.35) }
        if score >= 7 { return Color.brandGood }
        if score >= 4 { return .orange }
        return Color.brandDanger
    }

    private var todaySessions: [(session: StudySession, start: Double, end: Double)] {
        sessions.compactMap { session in
            guard let date = parseDate(session.createdAt), Calendar.current.isDateInToday(date) else { return nil }
            let end = minutesFromMidnight(date)
            let start = max(0, end - Double(session.minutes))
            return (session, start, end)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.raisedBackground)
                    ForEach(todaySessions, id: \.session.id) { item in
                        let width = max(3, (item.end - item.start) / 1440 * geo.size.width)
                        let xOffset = item.start / 1440 * geo.size.width
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color(for: item.session.postureScore))
                            .frame(width: width, height: geo.size.height - 8)
                            .offset(x: xOffset, y: 4)
                    }
                }
            }
            .frame(height: 44)

            HStack {
                ForEach(hourMarks, id: \.self) { hour in
                    Text("\(hour)시").font(.system(size: 11)).foregroundStyle(.secondary)
                    if hour != hourMarks.last { Spacer() }
                }
            }

            if todaySessions.isEmpty {
                Text("아직 오늘 기록된 학습이 없어요. 집중 시작을 눌러보세요.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
