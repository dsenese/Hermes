//
//  MicrophonePermissionManager.swift
//  Hermes
//
//  Created by GPT-5 on 8/7/25.
//

import Foundation
import AVFoundation
import AppKit

@MainActor
final class MicrophonePermissionManager: ObservableObject {
    static let shared = MicrophonePermissionManager()

    @Published private(set) var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    private var didRequestOnActivation = false

    private init() {
        // Observe app activation to request when foregrounded if needed
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAppDidBecomeActive),
                                               name: NSApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    func refreshStatus() {
        status = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Request microphone access if not determined. Calls completion with latest status.
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        refreshStatus()
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.refreshStatus()
                    completion?(granted)
                }
            }
        default:
            completion?(status == .authorized)
        }
    }

    /// Ensures we only auto-prompt once when the app first becomes active
    private func requestIfNeededOnActivation() {
        guard !didRequestOnActivation else { return }
        refreshStatus()
        if status == .notDetermined {
            didRequestOnActivation = true
            requestPermission(completion: nil)
        }
    }

    @objc private func handleAppDidBecomeActive() {
        requestIfNeededOnActivation()
    }
}


