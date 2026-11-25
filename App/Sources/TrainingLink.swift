import Foundation
import Security
import UIKit
import WorkoutCore

/// 3.1: the link to AMS Triathlon Training. One small Keychain item that three of the owner's apps share
/// (service ams.training.notes, account v1), and the open-the-other-app button.
/// Every failure is silent: the app then behaves as if there were no notes.
enum TrainingLink {
    static let service = "ams.training.notes"
    static let account = "v1"
    /// The training app's own group; this app lists it in its entitlements, after its own.
    static let group = "D24ENP83QQ.com.schabbauer.AMSWorkoutSync"

    private static var match: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrAccessGroup as String: group]
    }

    private static var skipping: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }

    static func read() -> Data? {
        var q = match
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    @discardableResult
    static func write(_ data: Data) -> Bool {
        let update = SecItemUpdate(match as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var add = match
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// A finished strength workout goes into the notes (read, change, write). Never in the app's own tests.
    static func add(_ note: TrainingNotes.Note?) {
        guard let note, !skipping,
              let data = TrainingNotes.adding(note, to: read()) else { return }
        write(data)
    }

    /// Undo Finish or Discard session: the note goes again.
    static func remove(id: String) {
        guard !skipping, let data = TrainingNotes.removing(id: id, from: read()) else { return }
        write(data)
    }

    // MARK: The other app

    static let trainingScheme = "amsworkoutsync"

    /// True when AMS Triathlon Training is on this device. A test launch can pretend with -triathloninstalled.
    static var trainingInstalled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-triathloninstalled") { return true }
        #endif
        guard let url = URL(string: "\(trainingScheme)://today") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func openTraining() {
        guard let url = URL(string: "\(trainingScheme)://today") else { return }
        UIApplication.shared.open(url)
    }

    /// Links into this app: amsworkouts://open brings it to the front; anything else is ignored.
    static func handle(_ url: URL) {
        // Nothing to do: opening the app is all `open` means. Other addresses change nothing.
        _ = url
    }
}
