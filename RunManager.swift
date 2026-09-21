import Foundation
import Combine
import AVFoundation

final class RunManager: ObservableObject {
    enum State {
        case idle, running, paused, finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var distance: Double = 0
    @Published private(set) var currentSpeed: Double = 0
    @Published private(set) var voiceCoachEnabled = true
    @Published private(set) var sessions: [RunSession] = []
    @Published private(set) var targetPaceSecondsPerKm: Double = 300

    let locationManager = LocationManager()
    let voiceCoach = VoiceCoach()

    private var timer: Timer?
    private var startedAt: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartedAt: Date?

    private let sessionsKey = "runtrack.sessions"
    private let voiceKey = "runtrack.voice.enabled"
    private let targetPaceKey = "targetPaceSecondsPerKm"

    init() {
        loadSessions()

        voiceCoachEnabled =
            UserDefaults.standard.object(forKey: voiceKey) as? Bool ?? true

        targetPaceSecondsPerKm =
            UserDefaults.standard.object(forKey: targetPaceKey) as? Double ?? 300

        voiceCoach.targetPaceSecondsPerKm = targetPaceSecondsPerKm
    }

    deinit {
        timer?.invalidate()
    }

    var currentPace: Double {
        guard currentSpeed > 0.5 else { return 0 }
        return 1000.0 / (currentSpeed * 60.0)
    }

    var averagePace: Double {
        guard distance > 0 else { return 0 }
        return (elapsed / 60.0) / (distance / 1000.0)
    }

    func setVoiceCoachEnabled(_ enabled: Bool) {
        voiceCoachEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: voiceKey)

        if !enabled {
            voiceCoach.reset()
        }
    }

    func setTargetPace(minutes: Int, seconds: Int) {
        let value = Double(minutes * 60 + seconds)

        guard value >= 180, value <= 655 else { return }

        targetPaceSecondsPerKm = value
        UserDefaults.standard.set(value, forKey: targetPaceKey)
        voiceCoach.targetPaceSecondsPerKm = value
    }

    func start() {
        guard state == .idle || state == .finished else { return }

        elapsed = 0
        distance = 0
        currentSpeed = 0
        pausedDuration = 0
        pauseStartedAt = nil
        startedAt = Date()
        state = .running

        voiceCoach.reset()
        voiceCoach.targetPaceSecondsPerKm = targetPaceSecondsPerKm

        locationManager.start()
        startTimer()
    }

    func pause() {
        guard state == .running else { return }

        updateElapsed()
        distance = locationManager.totalDistance
        currentSpeed = locationManager.currentSpeed

        state = .paused
        pauseStartedAt = Date()

        locationManager.stop()
        timer?.invalidate()
    }

    func resume() {
        guard state == .paused else { return }

        if let pauseStartedAt {
            pausedDuration += Date().timeIntervalSince(pauseStartedAt)
        }

        pauseStartedAt = nil
        state = .running

        locationManager.start()
        startTimer()
    }

    func finish() {
        guard state == .running || state == .paused else { return }

        if state == .paused, let pauseStartedAt {
            pausedDuration += Date().timeIntervalSince(pauseStartedAt)
        }

        updateElapsed()
        distance = locationManager.totalDistance
        currentSpeed = locationManager.currentSpeed

        locationManager.stop()
        timer?.invalidate()

        let session = RunSession(
            duration: elapsed,
            distance: distance,
            averagePace: averagePace
        )

        sessions.insert(session, at: 0)
        saveSessions()

        state = .finished
    }

    func reset() {
        timer?.invalidate()
        locationManager.stop()
        voiceCoach.reset()

        elapsed = 0
        distance = 0
        currentSpeed = 0
        startedAt = nil
        pausedDuration = 0
        pauseStartedAt = nil

        state = .idle
    }

    private func startTimer() {
        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in

            guard let self else { return }

            self.updateElapsed()
            self.distance = self.locationManager.totalDistance
            self.currentSpeed = self.locationManager.currentSpeed

            if self.voiceCoachEnabled {
                self.voiceCoach.announceIfNeeded(
                    distanceMeters: self.distance,
                    paceSecondsPerKm: self.currentPace * 60.0,
                    elapsedSeconds: self.elapsed
                )
            }
        }

        RunLoop.main.add(timer!, forMode: .common)
    }

    private func updateElapsed() {
        guard let startedAt else { return }

        elapsed = Date().timeIntervalSince(startedAt) - pausedDuration

        if elapsed < 0 {
            elapsed = 0
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func loadSessions() {
        guard
            let data = UserDefaults.standard.data(forKey: sessionsKey),
            let decoded = try? JSONDecoder().decode([RunSession].self, from: data)
        else {
            return
        }

        sessions = decoded
    }
}
