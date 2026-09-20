import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var totalDistance: Double = 0
    @Published var currentSpeed: Double = 0
    @Published var track: [CLLocationCoordinate2D] = []

    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
    }

    func start() {
        if authorizationStatus == .notDetermined {
            requestPermission()
        }

        lastLocation = nil
        totalDistance = 0
        currentSpeed = 0
        track.removeAll()

        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedAlways ||
            authorizationStatus == .authorizedWhenInUse {
            // Do not start automatically here; RunManager controls the session.
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            guard location.horizontalAccuracy >= 0 else { continue }

            if let previous = lastLocation {
                let delta = location.distance(from: previous)

                // Reject implausible GPS jumps.
                if delta < 100 {
                    totalDistance += delta
                }
            }

            if location.speed >= 0 {
                currentSpeed = location.speed
            }

            track.append(location.coordinate)
            lastLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal for the running session.
    }
}
