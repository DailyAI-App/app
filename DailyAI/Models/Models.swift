import Foundation

struct CalendarEvent: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var date: String // YYYY-MM-DD
    var detail: String?
}

struct RoadmapTopic: Codable, Hashable {
    var name: String
    var done: Bool
}

struct RoadmapStep: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var title: String
    // what to actually study for this step (roadmap.sh-style detail)...
    var detail: String?
    // ...plus the concrete named sub-topics, shown as their own small
    // boxes under the step (same as roadmap.sh), each individually
    // checkable to track specific competencies built.
    var topics: [RoadmapTopic]?
    var done: Bool
}

struct Roadmap: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var company: String
    // the target job/role at that company — was always implicitly
    // "developer"; now the user names it (marketer, designer, PM, ...).
    var role: String?
    var steps: [RoadmapStep]
}

struct RoadmapStepDraft: Codable {
    var title: String
    var detail: String?
    var topics: [String]?
}

struct RoadmapGenerateResult: Codable {
    var steps: [RoadmapStepDraft]
}

// AirPods-detected study presence, not posture.
struct StudyPresenceStats: Codable {
    var count: Int
    var abnormalCount: Int
    var average: Double?
}

struct StudyGoal: Codable {
    var title: String
    var examDate: String?
    var weeklyMinutes: Int
    var weeklyQuestions: Int
}

struct StudyMistake: Codable, Identifiable {
    let id: String
    var type: String
    var prompt: String
    var correctAnswer: String
    var explanation: String
}

struct StudySession: Codable, Identifiable {
    let id: String
    var minutes: Int
    var focusState: String
    var postureScore: Double?
    var createdAt: String
}

struct StudyAnalytics: Codable {
    var totalMinutes: Int
    var sessionCount: Int
    var averagePosture: Double?
    var mistakeCount: Int
    var currentStreak: Int
    var longestStreak: Int
}

struct StudyData: Codable {
    var goal: StudyGoal?
    var sessions: [StudySession]
    var mistakes: [StudyMistake]
    var analytics: StudyAnalytics
}

// one flexible shape covering all /api/trainer question types; the view
// switches on `type` and only reads the fields that type actually has.
struct QuizQuestion: Codable {
    var type: String
    var statement: String?
    var isTrue: Bool?
    var question: String?
    var options: [String]?
    var correctIndex: Int?
    var sentence: String?
    var answer: String?
    var flaw: String?
    var correction: String?
    var explanation: String
}

// the whole quiz, generated in one batch call.
struct QuizBatch: Codable {
    var questions: [QuizQuestion]
    // only present on the first call of a run — cache it and send it back
    // as `cachedText` on a restart instead of re-uploading the file.
    var sourceText: String?
}

struct QuizSession: Codable, Identifiable {
    let id: String
    var sourceName: String
    var questionCount: Int
}

enum QuestionType: String, CaseIterable, Identifiable {
    case mix, ox, mcq, fillBlank = "fill_blank", descriptive
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mix: return "자동 섞기"
        case .ox: return "OX"
        case .mcq: return "객관식"
        case .fillBlank: return "빈칸 채우기"
        case .descriptive: return "오류 찾기"
        }
    }
}

let autoMixOrder: [QuestionType] = [.mcq, .ox, .fillBlank, .descriptive]
