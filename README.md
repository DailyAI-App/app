# Daily AI — iOS/iPadOS + macOS app

One shared SwiftUI source tree (`DailyAI/`), two targets (`DailyAI` for
iPhone/iPad, `DailyAIMac` for Mac), covering everything the web app does:
일정(캘린더), 로드맵, 학습 코치(PDF/PPT 업로드 → 퀴즈 → 오답노트), 자세 코칭(AirPods).

No Clerk/OAuth on-device — the app authenticates every request with the
personal **연동 키** (API key) issued from the web app's `/posture` page,
the same Bearer credential every `/api/*` route accepts for clients that
can't hold a browser session.

No Xcode project generator was available in this environment, so the app
ships an XcodeGen `project.yml` rather than a generated `.xcodeproj`.

## Open and run

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then run
   `cd apps/DailyAI && xcodegen generate`.
2. Open `DailyAI.xcodeproj` in Xcode. For each target (`DailyAI`,
   `DailyAIMac`), choose a development team under **Signing & Capabilities**
   and change the bundle identifier if you plan to distribute it.
3. Run it (simulator/device for `DailyAI`, "My Mac" for `DailyAIMac`).
4. On first launch, open the web app's `/posture` page, copy the **연동 키**,
   and paste it (with the server URL) into the app's connect screen.

## What's implemented

- **일정**: list, add, delete calendar events.
- **로드맵**: generate a company's roadmap from real job postings, track step completion.
- **학습 코치**: pick a PDF or PPTX, pick a question type (or let it mix
  automatically) and a question count, and it runs the same OX/객관식/빈칸/서술형
  quiz loop as the web app — wrong answers land in the shared 오답노트.
- **자세 코칭**: AirPods Pro/Max motion via `CMHeadphoneMotionManager` (same API
  on iOS/iPadOS 14+ and macOS 14+), calibrate a neutral pose, auto-upload a
  score every 10 seconds while a session is running.

## Known scope cuts

- No voice assistant tab — the web's "도나" relies on the browser's Web Speech
  API, which has no native equivalent built here yet.
- No sandboxing/entitlements configured (`fileImporter` works unsandboxed);
  add the file-access entitlement before shipping to the App Store.
- The API key lives in `UserDefaults` via `@AppStorage` for this scaffold —
  move it to the Keychain before shipping production credentials.
