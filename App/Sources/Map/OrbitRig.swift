import Foundation
import Observation
import OrbitKit

/// Camera motion for the map: drag with inertia, pinch to zoom, smooth turns toward a
/// selected idea, and the morph between the Orbit and Tower layouts.
///
/// Only `isMoving` is observed. It un-pauses the map's animation timeline; everything else
/// changes every frame and is read directly while drawing.
@Observable
final class OrbitRig {
    private(set) var isMoving = false

    @ObservationIgnored var camera = Camera()
    @ObservationIgnored var morph: Double = 0
    @ObservationIgnored private(set) var morphTarget: Double = 0
    @ObservationIgnored private var velocity = (yaw: 0.0, pitch: 0.0)
    @ObservationIgnored private var target: (yaw: Double, pitch: Double)?
    @ObservationIgnored private var zoomTarget: Double?
    @ObservationIgnored private var lastTick: Date?
    @ObservationIgnored private var dragging = false
    @ObservationIgnored private var lastDrag: (translation: CGSize, time: Date)?
    @ObservationIgnored private var pinchBase: Double?
    @ObservationIgnored var reduceMotion = false

    static let dragGain = 0.0085

    private var needsAnimation: Bool {
        dragging || pinchBase != nil || target != nil || zoomTarget != nil
            || abs(velocity.yaw) > 0.02 || abs(velocity.pitch) > 0.02
            || morph != morphTarget
    }

    private func wake() {
        if !isMoving {
            lastTick = nil
            isMoving = true
        }
    }

    // MARK: Gestures

    func dragChanged(_ translation: CGSize, at time: Date) {
        if !dragging {
            dragging = true
            target = nil
            velocity = (0, 0)
            lastDrag = (translation, time)
            wake()
            return
        }
        guard let last = lastDrag else { return }
        let dx = Double(translation.width - last.translation.width)
        let dy = Double(translation.height - last.translation.height)
        camera.yaw += dx * Self.dragGain
        camera.pitch = clampPitch(camera.pitch + dy * Self.dragGain)
        let dt = max(1.0 / 120, time.timeIntervalSince(last.time))
        // Smooth the release speed so a jittery last frame doesn't fling the map.
        velocity.yaw = velocity.yaw * 0.6 + (dx * Self.dragGain / dt) * 0.4
        velocity.pitch = velocity.pitch * 0.6 + (dy * Self.dragGain / dt) * 0.4
        lastDrag = (translation, time)
    }

    func dragEnded() {
        dragging = false
        lastDrag = nil
        if reduceMotion { velocity = (0, 0) }
        velocity.yaw = max(-6, min(6, velocity.yaw))
        velocity.pitch = max(-4, min(4, velocity.pitch))
    }

    func pinchChanged(_ magnification: Double) {
        if pinchBase == nil {
            pinchBase = camera.zoom
            zoomTarget = nil
            wake()
        }
        camera.zoom = clampZoom((pinchBase ?? 1) * magnification)
    }

    func pinchEnded() {
        pinchBase = nil
    }

    // MARK: Commands

    /// Turn so that `point` faces the viewer.
    func focus(on point: Vec3, zoomIn: Bool) {
        let turn = Camera.facing(point)
        let wantZoom: Double? = zoomIn ? max(camera.zoom, 1.35) : nil
        if reduceMotion {
            camera.yaw = turn.yaw
            camera.pitch = turn.pitch
            if let wantZoom { camera.zoom = wantZoom }
            wake()
            return
        }
        velocity = (0, 0)
        target = (turn.yaw, turn.pitch)
        zoomTarget = wantZoom
        wake()
    }

    func zoom(by factor: Double) {
        let next = clampZoom((zoomTarget ?? camera.zoom) * factor)
        if reduceMotion {
            camera.zoom = next
        } else {
            zoomTarget = next
        }
        wake()
    }

    func setLayout(_ layout: MapLayout, animated: Bool) {
        morphTarget = layout == .tower ? 1 : 0
        if !animated || reduceMotion { morph = morphTarget }
        wake()
    }

    func resetView() {
        let home = Camera()
        if reduceMotion {
            camera = home
        } else {
            target = (home.yaw, home.pitch)
            zoomTarget = home.zoom
        }
        wake()
    }

    // MARK: Frame step

    /// Advance all motion to `now`. Called once per drawn frame.
    func step(to now: Date) {
        let dt: Double = lastTick.map { min(0.05, max(0, now.timeIntervalSince($0))) } ?? 0
        lastTick = now

        if let t = target {
            let k = 1 - exp(-dt * 7)
            let dYaw = Camera.shortestTurn(from: camera.yaw, to: t.yaw)
            let dPitch = t.pitch - camera.pitch
            camera.yaw += dYaw * k
            camera.pitch += dPitch * k
            if abs(dYaw) < 0.002 && abs(dPitch) < 0.002 { target = nil }
        }
        if let z = zoomTarget {
            let k = 1 - exp(-dt * 7)
            camera.zoom += (z - camera.zoom) * k
            if abs(z - camera.zoom) < 0.002 {
                camera.zoom = z
                zoomTarget = nil
            }
        }
        if !dragging {
            camera.yaw += velocity.yaw * dt
            camera.pitch = clampPitch(camera.pitch + velocity.pitch * dt)
            let decay = exp(-dt * 3.2)
            velocity.yaw *= decay
            velocity.pitch *= decay
            if abs(velocity.yaw) <= 0.02 && abs(velocity.pitch) <= 0.02 { velocity = (0, 0) }
        }
        if morph != morphTarget {
            let k = 1 - exp(-dt * 4.5)
            morph += (morphTarget - morph) * k
            if abs(morphTarget - morph) < 0.002 { morph = morphTarget }
        }
        // Keep yaw bounded so it never loses precision after many turns.
        camera.yaw = camera.yaw.truncatingRemainder(dividingBy: 2 * .pi)

        if isMoving && !needsAnimation {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.needsAnimation else { return }
                self.isMoving = false
            }
        }
    }

    private func clampPitch(_ value: Double) -> Double {
        min(Camera.pitchLimit, max(-Camera.pitchLimit, value))
    }

    private func clampZoom(_ value: Double) -> Double {
        min(Camera.zoomRange.upperBound, max(Camera.zoomRange.lowerBound, value))
    }
}
