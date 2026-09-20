import Foundation
import CoreLocation

struct RunSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let distance: Double
    let averagePace: Double

    init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval, distance: Double, averagePace: Double) {
        self.id = id
        self.date = date
        self.duration = duration
        self.distance = distance
        self.averagePace = averagePace
    }
}

struct TrackPoint {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
}
