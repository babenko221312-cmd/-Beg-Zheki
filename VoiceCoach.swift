import AVFoundation

final class VoiceCoach {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastAnnouncedKilometer = 0
    private var lastPaceWarningDate: Date?

    var enabled = true
    var targetPaceSecondsPerKm: Double = 300 // 5:00/km
    var warningToleranceSeconds: Double = 15
    var warningCooldown: TimeInterval = 60

    func reset() {
        lastAnnouncedKilometer = 0
        lastPaceWarningDate = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speak(_ text: String) {
        guard enabled else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }

    func announceIfNeeded(distanceMeters: Double, paceSecondsPerKm: Double, elapsedSeconds: TimeInterval) {
        guard enabled, distanceMeters > 0 else { return }

        let kilometer = Int(distanceMeters / 1000.0)
        if kilometer > lastAnnouncedKilometer {
            lastAnnouncedKilometer = kilometer

            let pace = Self.formatPace(paceSecondsPerKm)
            let time = Self.formatDuration(elapsedSeconds)
            speak("Километр \(kilometer). Темп \(pace) на километр. Время \(time).")
        }

        warnAboutPaceIfNeeded(paceSecondsPerKm: paceSecondsPerKm)
    }

    private func warnAboutPaceIfNeeded(paceSecondsPerKm: Double) {
        guard paceSecondsPerKm.isFinite,
              paceSecondsPerKm > 0,
              targetPaceSecondsPerKm > 0 else { return }

        let now = Date()
        if let last = lastPaceWarningDate, now.timeIntervalSince(last) < warningCooldown {
            return
        }

        let delta = paceSecondsPerKm - targetPaceSecondsPerKm

        if delta >= warningToleranceSeconds {
            lastPaceWarningDate = now
            speak("Темп ниже цели. Ускорьтесь.")
        } else if delta <= -warningToleranceSeconds {
            lastPaceWarningDate = now
            speak("Темп выше цели. Можно немного замедлиться.")
        }
    }

    static func formatPace(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "--:--" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
