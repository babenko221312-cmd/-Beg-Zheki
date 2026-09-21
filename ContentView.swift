import SwiftUI
import MapKit

struct ContentView: View {

    @EnvironmentObject private var runManager: RunManager
    @State private var showRoute = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            DashboardView(showRoute: $showRoute)
                .offset(x: showRoute ? -80 : 0)
                .opacity(showRoute ? 0.35 : 1)

            if showRoute {
                RouteView(showRoute: $showRoute)
                    .transition(.move(edge: .trailing))
                    .offset(x: max(0, dragOffset))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showRoute)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    if !showRoute && value.translation.width > 0 {
                        dragOffset = min(value.translation.width, 180)
                    } else if showRoute && value.translation.width < 0 {
                        dragOffset = max(value.translation.width, -180)
                    }
                }
                .onEnded { value in
                    if !showRoute && value.translation.width > 90 {
                        showRoute = true
                    } else if showRoute && value.translation.width < -90 {
                        showRoute = false
                    }
                    dragOffset = 0
                }
        )
    }
}

struct DashboardView: View {
    @EnvironmentObject private var runManager: RunManager
    @Binding var showRoute: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.orange.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        distanceCard

                        HStack(spacing: 12) {
                            MetricCard(title: "Время", value: formatDuration(runManager.elapsed), icon: "timer")
                            MetricCard(title: "Темп", value: formatPace(runManager.currentPace), icon: "speedometer")
                        }

                        HStack(spacing: 12) {
                            MetricCard(title: "Средний", value: formatPace(runManager.averagePace), icon: "chart.line.uptrend.xyaxis")
                            MetricCard(
                                title: "Скорость",
                                value: String(format: "%.1f", runManager.currentSpeed * 3.6) + " км/ч",
                                icon: "figure.run"
                            )
                        }
// Целевой темп
VStack(alignment: .leading, spacing: 10) {
    HStack {
        Label("Целевой темп", systemImage: "target")
            .font(.system(size: 14, weight: .semibold))

        Spacer()

        Text(formatTargetPace(runManager.targetPaceSecondsPerKm))
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.orange)
    }

    Picker(
        "Целевой темп",
        selection: Binding(
            get: {
                Int(runManager.targetPaceSecondsPerKm)
            },
            set: { value in
                runManager.setTargetPace(
                    minutes: value / 60,
                    seconds: value % 60
                )
            }
        )
    ) {
        ForEach(Array(stride(from: 180, through: 655, by: 5)), id: \.self) { seconds in
            Text(formatTargetPace(Double(seconds)))
                .tag(seconds)
        }
    }
    .pickerStyle(.menu)
    .tint(.orange)

    Text("Голосовой тренер предупредит, если темп отличается от цели более чем на 15 секунд.")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
}
.padding(.horizontal, 16)
.padding(.vertical, 13)
.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        HStack {
                            Label("Голосовой тренер", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 14, weight: .semibold))

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { runManager.voiceCoachEnabled },
                                set: { runManager.setVoiceCoachEnabled($0) }
                            ))
                            .labelsHidden()
                            .tint(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))

                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.orange)
                            Text("Свайп вправо — открыть маршрут")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "map")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .background(.thinMaterial, in: Capsule())

                        controls
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                runManager.locationManager.requestPermission()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("БЕГ ЖЕКИ")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(2)
                Text(statusText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }

            Spacer()

            Button {
                withAnimation { showRoute = true }
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.top, 8)
    }

    private var distanceCard: some View {
        VStack(spacing: 3) {
            Text(formatDistance(runManager.distance))
                .font(.system(size: 68, weight: .black, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
            Text("КМ")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2.5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var controls: some View {
        switch runManager.state {
        case .idle, .finished:
            Button {
                runManager.start()
            } label: {
                Label("Начать пробежку", systemImage: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            if runManager.state == .finished {
                Button("Новая пробежка") { runManager.reset() }
                    .font(.system(size: 15, weight: .semibold))
            }

        case .running:
            HStack(spacing: 12) {
                Button { runManager.pause() } label: {
                    Label("Пауза", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) { runManager.finish() } label: {
                    Label("Финиш", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
            }

        case .paused:
            HStack(spacing: 12) {
                Button { runManager.resume() } label: {
                    Label("Продолжить", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(role: .destructive) { runManager.finish() } label: {
                    Label("Финиш", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var statusText: String {
        switch runManager.state {
        case .idle: return "Готовы к пробежке?"
        case .running: return "Пробежка идёт"
        case .paused: return "Пауза"
        case .finished: return "Пробежка завершена"
        }
    }
}

struct RouteView: View {
    @EnvironmentObject private var runManager: RunManager
    @Binding var showRoute: Bool

    @State private var position: MapCameraPosition = .automatic
    @State private var lastCoordinate: CLLocationCoordinate2D?

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                if runManager.locationManager.track.count >= 2 {
                    MapPolyline(coordinates: runManager.locationManager.track)
                        .stroke(.orange, lineWidth: 7)
                }

                if let first = runManager.locationManager.track.first {
                    Annotation("Старт", coordinate: first) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(.green)
                                .frame(width: 14, height: 14)
                        }
                        .shadow(radius: 3)
                    }
                }

                if let last = runManager.locationManager.track.last {
                    Annotation("Вы здесь", coordinate: last) {
                        ZStack {
                            Circle()
                                .fill(.orange.opacity(0.22))
                                .frame(width: 44, height: 44)
                            Circle()
                                .fill(.orange)
                                .frame(width: 18, height: 18)
                            Circle()
                                .fill(.white)
                                .frame(width: 7, height: 7)
                        }
                        .shadow(radius: 4)
                    }
                }

                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        withAnimation { showRoute = false }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .background(.regularMaterial, in: Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("МАРШРУТ")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(2)
                        Text(runManager.locationManager.track.count >= 2 ? "GPS записывает путь" : "Ожидание GPS")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer()

                HStack {
                    Button {
                        centerOnLatestLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 46, height: 46)
                            .background(.regularMaterial, in: Circle())
                    }

                    Spacer()

                    if runManager.locationManager.track.count >= 2 {
                        Label("\(runManager.locationManager.track.count) точек", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(.regularMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 145)
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    RouteStat(value: formatDistance(runManager.distance) + " км", title: "Дистанция")
                    RouteStat(value: formatPace(runManager.currentPace), title: "Темп")
                    RouteStat(value: formatDuration(runManager.elapsed), title: "Время")
                }

                Text("Свайп влево — вернуться")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .onAppear {
            runManager.locationManager.requestPermission()
            centerOnLatestLocation()
        }
        .onChange(of: runManager.locationManager.track.count) { _, _ in
            centerOnLatestLocation(animated: true)
        }
    }

    private func centerOnLatestLocation(animated: Bool = false) {
        guard let coordinate = runManager.locationManager.track.last else { return }

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 900,
            longitudinalMeters: 900
        )

        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                position = .region(region)
            }
        } else {
            position = .region(region)
        }
        lastCoordinate = coordinate
    }
}

struct RouteStat: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 21))
    }
}

struct HistoryView: View {
    @EnvironmentObject private var runManager: RunManager

    var body: some View {
        NavigationStack {
            List {
                if runManager.sessions.isEmpty {
                    ContentUnavailableView(
                        "Нет пробежек",
                        systemImage: "figure.run",
                        description: Text("Завершённые тренировки появятся здесь.")
                    )
                } else {
                    ForEach(runManager.sessions) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(session.date, format: .dateTime.day().month().year().hour().minute())
                                .font(.headline)

                            HStack {
                                Text(String(format: "%.2f км", session.distance / 1000))
                                Text("•")
                                Text(formatDuration(session.duration))
                                Text("•")
                                Text(formatPace(session.averagePace))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("История")
        }
    }
}

func formatDistance(_ meters: Double) -> String {
    String(format: "%.2f", meters / 1000.0)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}

func formatPace(_ minutesPerKm: Double) -> String {
    guard minutesPerKm.isFinite, minutesPerKm > 0 else { return "--:--" }
    let totalSeconds = Int(minutesPerKm * 60.0)
    return String(format: "%d:%02d /км", totalSeconds / 60, totalSeconds % 60)
}
func formatTargetPace(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d /км", total / 60, total % 60)
}
