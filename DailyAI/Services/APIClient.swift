import Foundation

enum APIError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return "서버 응답을 처리하지 못했어요."
        }
    }
}

// Every call authenticates with the personal API key from the web app's
// /posture (study presence) page — the same Bearer credential every /api/*
// route accepts for companion apps that can't hold a Clerk browser session.
struct APIClient {
    let baseURL: String
    let apiKey: String

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil, contentType: String? = "application/json") -> URLRequest {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: URL(string: trimmed + path)!)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if !(200..<300).contains(http.statusCode) {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data), let message = errorBody["error"] {
                throw APIError.server(message)
            }
            throw APIError.server("요청이 실패했어요 (\(http.statusCode)).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: Calendar

    func fetchCalendar() async throws -> [CalendarEvent] {
        struct Response: Decodable { var events: [CalendarEvent] }
        let r: Response = try await send(makeRequest(path: "/api/calendar"))
        return r.events
    }

    func addCalendarEvent(title: String, date: String) async throws -> [CalendarEvent] {
        struct Response: Decodable { var events: [CalendarEvent] }
        let body = try JSONSerialization.data(withJSONObject: ["title": title, "date": date])
        let r: Response = try await send(makeRequest(path: "/api/calendar", method: "POST", body: body))
        return r.events
    }

    func deleteCalendarEvent(id: String) async throws -> [CalendarEvent] {
        struct Response: Decodable { var events: [CalendarEvent] }
        let r: Response = try await send(makeRequest(path: "/api/calendar/\(id)", method: "DELETE", body: nil))
        return r.events
    }

    // MARK: Roadmap

    func fetchRoadmaps() async throws -> [Roadmap] {
        struct Response: Decodable { var roadmaps: [Roadmap] }
        let r: Response = try await send(makeRequest(path: "/api/roadmaps"))
        return r.roadmaps
    }

    func generateRoadmapSteps(company: String) async throws -> [String] {
        let body = try JSONSerialization.data(withJSONObject: ["company": company])
        let result: RoadmapGenerateResult = try await send(makeRequest(path: "/api/roadmap", method: "POST", body: body))
        return result.steps
    }

    func saveRoadmap(company: String, steps: [String]) async throws -> [Roadmap] {
        struct Response: Decodable { var roadmaps: [Roadmap] }
        let body = try JSONSerialization.data(withJSONObject: ["company": company, "steps": steps])
        let r: Response = try await send(makeRequest(path: "/api/roadmaps", method: "POST", body: body))
        return r.roadmaps
    }

    func toggleRoadmapStep(roadmapId: String, stepId: String) async throws -> [Roadmap] {
        struct Response: Decodable { var roadmaps: [Roadmap] }
        let body = try JSONSerialization.data(withJSONObject: ["stepId": stepId])
        let r: Response = try await send(makeRequest(path: "/api/roadmaps/\(roadmapId)", method: "PATCH", body: body))
        return r.roadmaps
    }

    func deleteRoadmap(id: String) async throws -> [Roadmap] {
        struct Response: Decodable { var roadmaps: [Roadmap] }
        let r: Response = try await send(makeRequest(path: "/api/roadmaps/\(id)", method: "DELETE", body: nil))
        return r.roadmaps
    }

    // MARK: Study presence (AirPods-detected "studying" signal)

    func fetchStudyPresence() async throws -> StudyPresenceStats {
        try await send(makeRequest(path: "/api/posture"))
    }

    func postStudyPresenceScore(_ score: Double, source: String) async throws -> StudyPresenceStats {
        let body = try JSONSerialization.data(withJSONObject: ["score": score, "source": source])
        return try await send(makeRequest(path: "/api/posture", method: "POST", body: body))
    }

    // MARK: Study

    func fetchStudy() async throws -> StudyData {
        try await send(makeRequest(path: "/api/study"))
    }

    func saveStudySession(minutes: Int, focusState: String, presenceScore: Double?) async throws -> StudyData {
        var payload: [String: Any] = ["action": "session", "minutes": minutes, "focusState": focusState]
        payload["postureScore"] = presenceScore ?? NSNull()
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await send(makeRequest(path: "/api/study", method: "POST", body: body))
    }

    // one quiz run = one chapter in 오답노트.
    func createQuizSession(sourceName: String, questionCount: Int) async throws -> QuizSession {
        let body = try JSONSerialization.data(withJSONObject: ["sourceName": sourceName, "questionCount": questionCount])
        return try await send(makeRequest(path: "/api/trainer/sessions", method: "POST", body: body))
    }

    func logMistake(type: String, prompt: String, options: [String]?, correctAnswer: String, userAnswer: String, explanation: String, sessionId: String?) async {
        var payload: [String: Any] = ["type": type, "prompt": prompt, "correctAnswer": correctAnswer, "userAnswer": userAnswer, "explanation": explanation]
        if let options { payload["options"] = options }
        if let sessionId { payload["sessionId"] = sessionId }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        _ = try? await URLSession.shared.data(for: makeRequest(path: "/api/trainer/attempts", method: "POST", body: body))
    }

    func deleteMistake(id: String) async {
        _ = try? await URLSession.shared.data(for: makeRequest(path: "/api/trainer/attempts/\(id)", method: "DELETE", body: nil))
    }

    // First call in a quiz run uploads the file; every later question in
    // that run should pass `cachedText` (from the first response's
    // `sourceText`) instead — re-parsing the same PDF/PPTX on every
    // question was the main source of slow question generation.
    // `exclude` carries every prompt already asked this run so the model
    // doesn't repeat itself.
    func generateQuestion(fileData: Data?, fileName: String, mimeType: String, cachedText: String?, type: String, exclude: [String]) async throws -> QuizQuestion {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("type", type)
        if let excludeJSON = try? JSONSerialization.data(withJSONObject: exclude), let excludeString = String(data: excludeJSON, encoding: .utf8) {
            appendField("exclude", excludeString)
        }

        if let cachedText {
            appendField("text", cachedText)
        } else if let fileData {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = makeRequest(path: "/api/trainer", method: "POST", body: body, contentType: nil)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }
}
