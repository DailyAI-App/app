import CoreMotion
import Foundation
import UserNotifications
#if os(macOS)
import AppKit
#else
import AudioToolbox
#endif

// Detects whether the user is actively studying — AirPods worn (motion
// updates flowing) and the head reasonably still (reading/listening, not
// walking around or talking) — rather than correcting posture angle. Also
// nudges the user (sound + notification) if that can't be confirmed for too long.
@MainActor
final class HeadphoneMotionService: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isStudying = false
    @Published private(set) var presenceScore: Double = 0

    private let manager = CMHeadphoneMotionManager()
    private var lastAttitude: (pitch: Double, roll: Double, yaw: Double)?
    private var recentMovement: [Double] = []
    private let windowSize = 20

    // ponytail: movement-variance threshold is a simple heuristic, not a
    // validated "studying" classifier — tune this if it over/under-reports.
    private let movementThreshold = 0.015

    // attitude is gravity-referenced (no manual calibration needed), so an
    // extreme pitch/roll reliably means "head face-down on the desk" or
    // "reclined/lying down" — stillness alone can't tell those apart from
    // quiet reading, which is what regressed detection after dropping the
    // old posture-angle check. Tune these if real desks/chairs clip early.
    private let maxPitchRadians = 60.0 * .pi / 180
    private let maxRollRadians = 50.0 * .pi / 180

    // nudge: how long "studying" can stay unconfirmed before alerting, and
    // how often to repeat the nudge while it's still unconfirmed.
    private let notStudyingAlertThreshold: TimeInterval = 90
    private let alertCooldown: TimeInterval = 60
    private var notStudyingSince: Date?
    private var lastAlertAt: Date?

    override init() {
        super.init()
        isAvailable = manager.isDeviceMotionAvailable
        UNUserNotificationCenter.current().delegate = self
    }

    func start() {
        guard isAvailable, !isCapturing else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, error == nil, let motion else { return }
            Task { @MainActor in
                self.ingest(motion.attitude.pitch, motion.attitude.roll, motion.attitude.yaw)
            }
        }
        isCapturing = true
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isCapturing = false
        isStudying = false
        presenceScore = 0
        lastAttitude = nil
        recentMovement.removeAll()
        notStudyingSince = nil
        lastAlertAt = nil
    }

    private func ingest(_ pitch: Double, _ roll: Double, _ yaw: Double) {
        defer { lastAttitude = (pitch, roll, yaw) }
        guard let last = lastAttitude else { return }

        let delta = abs(pitch - last.pitch) + abs(roll - last.roll) + abs(yaw - last.yaw)
        recentMovement.append(delta)
        if recentMovement.count > windowSize { recentMovement.removeFirst() }
        guard recentMovement.count >= 5 else { return }

        let averageMovement = recentMovement.reduce(0, +) / Double(recentMovement.count)
        let stabilityScore = max(0, min(10, 10 * (1 - averageMovement / movementThreshold)))
        let uprightEnough = abs(pitch) < maxPitchRadians && abs(roll) < maxRollRadians

        presenceScore = uprightEnough ? stabilityScore : 0
        isStudying = uprightEnough && averageMovement < movementThreshold
        evaluateAlert()
    }

    private func evaluateAlert() {
        if isStudying {
            notStudyingSince = nil
            return
        }
        let now = Date()
        let since = notStudyingSince ?? now
        if notStudyingSince == nil { notStudyingSince = now }
        guard now.timeIntervalSince(since) >= notStudyingAlertThreshold else { return }
        if let lastAlertAt, now.timeIntervalSince(lastAlertAt) < alertCooldown { return }
        lastAlertAt = now
        fireAlert()
    }

    private func fireAlert() {
        #if os(macOS)
        NSSound.beep()
        #else
        AudioServicesPlaySystemSound(1007)
        #endif

        let content = UNMutableNotificationContent()
        content.title = "집중이 흐트러진 것 같아요"
        content.body = "AirPods로 학습 중인지 확인이 안 돼요. 자세를 바로잡고 다시 집중해볼까요?"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "study-presence-alert", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension HeadphoneMotionService: UNUserNotificationCenterDelegate {
    // show the nudge even while the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
