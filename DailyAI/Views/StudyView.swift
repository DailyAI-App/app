import SwiftUI
import UniformTypeIdentifiers

struct StudyView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    @StateObject private var voice = VoiceAnswerService()
    @State private var studyData: StudyData?
    @State private var showingFilePicker = false
    @State private var fileURL: URL?

    @State private var typeMode: QuestionType = .mix
    @State private var questionCount = 10
    @State private var questionNumber = 0
    @State private var completed = 0
    @State private var sessionDone = false

    @State private var question: QuizQuestion?
    @State private var isLoading = false
    @State private var error: String?
    @State private var voiceMode = false

    @State private var selectedOx: Bool?
    @State private var selectedIndex: Int?
    @State private var blankInput = ""
    @State private var graded: Bool?

    // one "시작" = one chapter in 오답노트; cachedText/askedPrompts avoid
    // re-parsing the file and repeating questions on every call.
    @State private var quizSessionId: String?
    @State private var cachedText: String?
    @State private var askedPrompts: [String] = []

    private var client: APIClient { APIClient(baseURL: settings.baseURL, apiKey: settings.apiKey) }
    private let pptxType = UTType(filenameExtension: "pptx") ?? .data

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(eyebrow: "SMART STUDY", title: "학습 코치", subtitle: "자료를 올리고 나만의 퀴즈 세션을 시작하세요")
                    if let error { Text(error).foregroundStyle(Color.brandDanger).font(.footnote) }

                    Button {
                        voiceMode.toggle()
                        if voiceMode, let question, graded == nil { askQuestionAloud(question) }
                    } label: {
                        Label("🎙️ 음성으로 풀기", systemImage: "waveform")
                    }
                    .buttonStyle(.chip(selected: voiceMode))

                    if voiceMode, question != nil {
                        Text(voice.isSpeaking ? "AI가 문제를 읽어주고 있어요…" : voice.isListening ? (voice.liveTranscript.isEmpty ? "답을 말해보세요…" : "듣고 있어요: \(voice.liveTranscript)") : "답변을 기다리고 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if question == nil && !sessionDone {
                        uploadCard
                    }
                    if questionNumber > 0 && !sessionDone {
                        progressCard
                    }
                    if let question {
                        questionCard(question)
                    }
                    if sessionDone {
                        completedCard
                    }
                    if let studyData {
                        summaryCard(studyData)
                        mistakesCard(studyData)
                    }
                }
                .padding()
            }
            .background(Color.pageBackground)
            .navigationTitle("학습 코치")
            .task { await loadStudy() }
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.pdf, pptxType]) { result in
                if case .success(let url) = result {
                    fileURL = url
                    cachedText = nil
                    Task { await startSession(url) }
                }
            }
            .onChange(of: questionNumber) { _, _ in
                guard voiceMode, let question, graded == nil else { return }
                askQuestionAloud(question)
            }
            .onChange(of: graded) { _, newValue in
                guard voiceMode, let newValue, let question else { return }
                speakResult(question, isCorrect: newValue)
            }
        }
    }

    private var uploadCard: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.bentoLavender)
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }
                .frame(width: 72, height: 72)
                SectionHeading(eyebrow: "강의 자료", title: "올리면 바로 학습이 시작돼요")
                Text("PDF 또는 PPTX를 선택해 맞춤형 퀴즈를 만들어요.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button(isLoading ? "문제를 만드는 중…" : "PDF·PPT 선택하기") { showingFilePicker = true }
                    .buttonStyle(.primary(fullWidth: true))
                    .disabled(isLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("문제 유형").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    FlowChips(items: QuestionType.allCases, label: \.label, isSelected: { $0 == typeMode }) { typeMode = $0 }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("문제 수").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    FlowChips(items: [5, 10, 20], label: { "\($0)개" }, isSelected: { $0 == questionCount }) { questionCount = $0 }
                }
            }
            .frame(width: 280)
            .padding(18)
            .background(Color.raisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(24)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.055), lineWidth: 1))
        .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "학습 세션")
                Spacer()
                Text("\(questionNumber) / \(questionCount)")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brandDim, in: Capsule())
            }
            ProgressView(value: Double(completed), total: Double(questionCount))
                .tint(.brand)
                .scaleEffect(x: 1, y: 1.35, anchor: .center)
        }
        .cardStyle()
    }

    private var completedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(eyebrow: "완료", title: "학습 세션 완료")
            Text("\(questionCount)문제를 모두 풀었어요. 틀린 문제는 아래 오답노트에 쌓여요.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("다시 시작") {
                sessionDone = false
                if let fileURL { Task { await startSession(fileURL) } }
            }
            .buttonStyle(.primary)
        }
        .cardStyle()
    }

    @ViewBuilder
    private func questionCard(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            switch question.type {
            case "ox":
                Eyebrow(text: "참일까요, 거짓일까요?")
                Text(question.statement ?? "").font(.system(size: 15))
                HStack {
                    answerButton("참", isSelected: selectedOx == true) { answerOx(true) }
                    answerButton("거짓", isSelected: selectedOx == false) { answerOx(false) }
                }
            case "mcq":
                Eyebrow(text: "맞는 보기를 골라보세요")
                Text(question.question ?? "").font(.system(size: 15))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array((question.options ?? []).enumerated()), id: \.offset) { index, option in
                        answerButton(option, isSelected: selectedIndex == index, fullWidth: true) { answerMcq(index) }
                    }
                }
            case "fill_blank":
                Eyebrow(text: "빈칸에 들어갈 말은?")
                Text(question.sentence ?? "").font(.system(size: 15))
                HStack {
                    TextField("정답 입력", text: $blankInput).textFieldStyle(.roundedBorder)
                    Button("제출") { answerBlank(question) }
                        .buttonStyle(.primary)
                        .disabled(graded != nil || blankInput.isEmpty)
                }
            default: // descriptive
                Eyebrow(text: "이 설명 중 한 군데가 틀렸어요")
                Text(question.explanation).font(.system(size: 15))
                if graded == nil {
                    Button("정답 확인") { revealDescriptive() }.buttonStyle(.primary)
                }
            }

            if let graded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(graded ? "정답이에요" : "틀렸어요").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(graded ? Color.brandGood : Color.brandDanger)
                    if question.type == "descriptive" {
                        Text("틀린 부분: \(question.flaw ?? "")")
                        Text("올바른 설명: \(question.correction ?? "")")
                    } else {
                        Text(question.explanation)
                    }
                    Button(questionNumber == questionCount ? "학습 완료" : "다음 문제") { Task { await nextQuestion() } }
                        .buttonStyle(.primary)
                        .padding(.top, 4)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(14)
                .background(Color.raisedBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .cardStyle()
    }

    private func answerButton(_ title: String, isSelected: Bool, fullWidth: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
        }
        .buttonStyle(.chip(selected: isSelected))
        .disabled(graded != nil)
    }

    private func summaryCard(_ data: StudyData) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            studyStatCard("이번 주 학습", formatMinutes(data.analytics.totalMinutes), "clock.fill", Color.bentoLavender)
            studyStatCard("연속 학습 스트릭", "\(data.analytics.currentStreak)일", "flame.fill", Color.bentoYellow)
            studyStatCard("오답", "\(data.analytics.mistakeCount)개", "arrow.uturn.backward", Color.bentoPink)
            studyStatCard("학습 감지 평균", data.analytics.averagePosture.map { String(format: "%.1f", $0) } ?? "—", "waveform", Color.bentoMint)
        }
    }

    private func studyStatCard(_ label: String, _ value: String, _ icon: String, _ background: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.brand)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding(18)
        .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func mistakesCard(_ data: StudyData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "오답노트", title: "다시 보면 좋아요")
            if data.mistakes.isEmpty {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.brandGood)
                    Text("아직 틀린 문제가 없어요")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            ForEach(data.mistakes) { mistake in
                VStack(alignment: .leading, spacing: 4) {
                    Text(mistake.prompt).font(.system(size: 13, weight: .medium))
                    Text("정답: \(mistake.correctAnswer)").font(.caption).foregroundStyle(Color.brandGood)
                    Text(mistake.explanation).font(.caption).foregroundStyle(.secondary)
                }
                if mistake.id != data.mistakes.last?.id { Divider() }
            }
        }
        .cardStyle()
    }

    // MARK: actions

    private func loadStudy() async {
        studyData = try? await client.fetchStudy()
    }

    private func startSession(_ url: URL) async {
        questionNumber = 1
        completed = 0
        sessionDone = false
        askedPrompts = []
        do {
            quizSessionId = try await client.createQuizSession(sourceName: url.lastPathComponent, questionCount: questionCount).id
        } catch {
            quizSessionId = nil // mistakes still log without a chapter if this fails
        }
        await generate(url: url, number: 1)
    }

    private func nextQuestion() async {
        guard let fileURL else { return }
        if questionNumber >= questionCount {
            question = nil
            sessionDone = true
            await loadStudy()
            return
        }
        questionNumber += 1
        await generate(url: fileURL, number: questionNumber)
    }

    private func generate(url: URL, number: Int) async {
        isLoading = true
        error = nil
        resetAnswerState()
        defer { isLoading = false }
        do {
            let type = typeMode == .mix ? autoMixOrder[(number - 1) % autoMixOrder.count].rawValue : typeMode.rawValue
            let mime = url.pathExtension.lowercased() == "pdf"
                ? "application/pdf"
                : "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            let fileData = cachedText == nil ? try Data(contentsOf: url) : nil
            let result = try await client.generateQuestion(fileData: fileData, fileName: url.lastPathComponent, mimeType: mime, cachedText: cachedText, type: type, exclude: askedPrompts)
            if let sourceText = result.sourceText { cachedText = sourceText }
            askedPrompts.append(promptSignature(result))
            question = result
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func promptSignature(_ q: QuizQuestion) -> String {
        switch q.type {
        case "ox": return q.statement ?? ""
        case "mcq": return q.question ?? ""
        case "fill_blank": return q.sentence ?? ""
        default: return q.explanation
        }
    }

    private func resetAnswerState() {
        selectedOx = nil
        selectedIndex = nil
        blankInput = ""
        graded = nil
    }

    private func answerOx(_ value: Bool) {
        guard let question, graded == nil else { return }
        selectedOx = value
        let isCorrect = value == (question.isTrue ?? false)
        graded = isCorrect
        completed += 1
        if !isCorrect {
            Task { await client.logMistake(type: "ox", prompt: question.statement ?? "", options: nil, correctAnswer: (question.isTrue ?? false) ? "참" : "거짓", userAnswer: value ? "참" : "거짓", explanation: question.explanation, sessionId: quizSessionId) }
        }
    }

    private func answerMcq(_ index: Int) {
        guard let question, graded == nil, let options = question.options, let correctIndex = question.correctIndex else { return }
        selectedIndex = index
        let isCorrect = index == correctIndex
        graded = isCorrect
        completed += 1
        if !isCorrect {
            Task { await client.logMistake(type: "mcq", prompt: question.question ?? "", options: options, correctAnswer: options[correctIndex], userAnswer: options[index], explanation: question.explanation, sessionId: quizSessionId) }
        }
    }

    private func answerBlank(_ question: QuizQuestion) {
        guard graded == nil, let answer = question.answer, !blankInput.isEmpty else { return }
        let isCorrect = blankInput.trimmingCharacters(in: .whitespaces).lowercased() == answer.trimmingCharacters(in: .whitespaces).lowercased()
        graded = isCorrect
        completed += 1
        if !isCorrect {
            Task { await client.logMistake(type: "fill_blank", prompt: question.sentence ?? "", options: nil, correctAnswer: answer, userAnswer: blankInput, explanation: question.explanation, sessionId: quizSessionId) }
        }
    }

    private func revealDescriptive() {
        graded = true
        completed += 1
    }

    // MARK: voice teaching mode

    private func questionPromptText(_ q: QuizQuestion) -> String {
        switch q.type {
        case "ox":
            return q.statement ?? ""
        case "mcq":
            let optionsText = (q.options ?? []).enumerated().map { "\($0.offset + 1)번 \($0.element)" }.joined(separator: ", ")
            return "\(q.question ?? "") 보기는 \(optionsText) 입니다."
        case "fill_blank":
            return (q.sentence ?? "").replacingOccurrences(of: "____", with: "빈칸")
        default:
            return q.explanation
        }
    }

    private func askQuestionAloud(_ q: QuizQuestion) {
        voice.speak(questionPromptText(q)) {
            voice.listen { transcript in applySpokenAnswer(transcript, to: q) }
        }
    }

    private func applySpokenAnswer(_ transcript: String, to q: QuizQuestion) {
        switch q.type {
        case "ox":
            if let value = matchOx(transcript) { answerOx(value) }
        case "mcq":
            if let index = matchMcq(transcript, options: q.options ?? []) { answerMcq(index) }
        case "fill_blank":
            blankInput = transcript
            answerBlank(q)
        default:
            revealDescriptive()
        }
    }

    private func matchOx(_ transcript: String) -> Bool? {
        let t = transcript.replacingOccurrences(of: " ", with: "")
        if t.contains("거짓") || t.contains("아니") || t.contains("틀려") || t.contains("틀렸") { return false }
        if t.contains("참") || t.contains("맞아") || t.contains("맞다") || t.contains("그래") { return true }
        return nil
    }

    private let numberWords = ["일", "이", "삼", "사"]
    private func matchMcq(_ transcript: String, options: [String]) -> Int? {
        let t = transcript.replacingOccurrences(of: " ", with: "")
        for i in 0..<options.count {
            if t.contains("\(i + 1)번") || (i < numberWords.count && t.contains("\(numberWords[i])번")) { return i }
        }
        return options.firstIndex { !$0.isEmpty && t.contains($0.replacingOccurrences(of: " ", with: "")) }
    }

    private func speakResult(_ q: QuizQuestion, isCorrect: Bool) {
        let prefix = isCorrect ? "정답이에요. " : "틀렸어요. "
        let explanation = q.type == "descriptive" ? "틀린 부분은 \(q.flaw ?? ""). 올바른 설명은 \(q.correction ?? "")." : q.explanation
        voice.speak(prefix + explanation) {}
    }
}
