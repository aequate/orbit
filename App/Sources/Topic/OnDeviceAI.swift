import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model (iOS 26+, Apple Intelligence). Nothing leaves the phone.
/// On older systems or ineligible devices, the app falls back to reviewed notes.
enum OnDeviceAI {
    enum Status: Equatable {
        case available
        case unavailable(String)

        var isAvailable: Bool { self == .available }
    }

    struct Unavailable: Error {}

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unavailable("This iPhone can't run Apple Intelligence, so answers come from Orbit's reviewed notes.")
            case .unavailable(.modelNotReady):
                return .unavailable("Apple Intelligence is still getting ready. Until then, answers come from Orbit's reviewed notes.")
            default:
                return .unavailable("Turn on Apple Intelligence in Settings for live answers. Until then, answers come from Orbit's reviewed notes.")
            }
        }
        #endif
        return .unavailable("Live answers need iOS 26 with Apple Intelligence. Answers here come from Orbit's reviewed notes.")
    }

    static func respond(to prompt: String, instructions: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw Unavailable()
    }
}
