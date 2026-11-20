import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    @State private var events: [CalendarEvent] = []
    @State private var newTitle = ""
    @State private var newDate = Date()
    @State private var isLoading = true
    @State private var error: String?

    private var client: APIClient { APIClient(baseURL: settings.baseURL, apiKey: settings.apiKey) }
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(eyebrow: "DAILY PLANNER", title: "오늘의 일정", subtitle: "한눈에 확인하고 차분하게 계획해요")

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeading(eyebrow: "새 일정", title: "무엇을 계획하고 있나요?")
                            TextField("일정 제목을 입력하세요", text: $newTitle)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16, weight: .medium))
                                .padding(14)
                                .background(Color.raisedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            HStack(spacing: 10) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.brand)
                                DatePicker("날짜", selection: $newDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.raisedBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .frame(maxWidth: .infinity)
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "빠른 추가")
                            Text(newDate.formatted(.dateTime.month().day()))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Button("일정 추가") { Task { await add() } }
                                .buttonStyle(.primary(fullWidth: true))
                                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .frame(width: 180)
                        .cardStyle()
                    }

                    if let error { Text(error).foregroundStyle(Color.brandDanger).font(.footnote) }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(eyebrow: "캘린더", title: "다가오는 일정")
                        if events.isEmpty && !isLoading {
                            VStack(spacing: 8) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.brand.opacity(0.65))
                                Text("등록된 일정이 없어요")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        }
                        ForEach(events) { event in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.bentoLavender)
                                    Text(displayDate(event.date).replacingOccurrences(of: "월 ", with: "/").replacingOccurrences(of: "일", with: ""))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.brand)
                                }
                                .frame(width: 58, height: 58)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(displayDate(event.date))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task { await delete(event) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.brandDanger)
                                        .frame(width: 32, height: 32)
                                        .background(Color.brandDanger.opacity(0.08), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            if event.id != events.last?.id { Divider() }
                        }
                    }
                    .cardStyle()
                }
                .padding()
            }
            .background(Color.pageBackground)
            .navigationTitle("일정")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func displayDate(_ raw: String) -> String {
        guard let date = Self.dateFormatter.date(from: raw) else { return raw }
        return Self.displayFormatter.string(from: date)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await client.fetchCalendar()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func add() async {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newTitle = ""
        do {
            events = try await client.addCalendarEvent(title: title, date: Self.dateFormatter.string(from: newDate))
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ event: CalendarEvent) async {
        do {
            events = try await client.deleteCalendarEvent(id: event.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
