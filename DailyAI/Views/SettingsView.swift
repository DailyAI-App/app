import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    var isOnboarding: Bool = false
    @State private var didImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isOnboarding {
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.brand)
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .frame(width: 44, height: 44)
                            Text("Daily AI")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("나만의 성장 공간")
                                .font(.system(size: 14, weight: .semibold))
                            Text("웹 앱의 /posture 페이지 하단에서 연동 키를 발급받아 여기에 붙여넣으세요.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Button {
                                didImport = settings.importFromClipboard()
                            } label: {
                                Label(didImport ? "연동 키를 찾았어요" : "클립보드에서 자동 입력", systemImage: didImport ? "checkmark.circle.fill" : "doc.on.clipboard")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.primary(fullWidth: true))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "서버")
                        TextField("https://your-app.vercel.app", text: $settings.baseURL)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "연동 키")
                        SecureField("pk_...", text: $settings.apiKey)
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                        Text("일정, 로드맵, 학습 코치, 자세 코칭 모두 이 키로 같은 웹 계정의 데이터를 공유합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .cardStyle()
                }
                .padding()
            }
            .background(Color.pageBackground)
            .navigationTitle(isOnboarding ? "연결하기" : "설정")
        }
    }
}
