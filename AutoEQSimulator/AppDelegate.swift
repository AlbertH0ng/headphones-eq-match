//
//  AppDelegate.swift
//  AutoEQSimulator
//
//  Created by Anting Hong on 22/09/2024.
//

import Cocoa
import AVFoundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Request microphone access
        requestMicrophoneAccess()
    }

    func requestMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("Microphone access authorized")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Microphone access granted")
                } else {
                    print("Microphone access denied")
                    DispatchQueue.main.async {
                        self.showMicrophoneAccessAlert()
                    }
                }
            }
        case .denied, .restricted:
            print("Microphone access denied or restricted")
            DispatchQueue.main.async {
                self.showMicrophoneAccessAlert()
            }
        @unknown default:
            fatalError("Unknown authorization status")
        }
    }

    func showMicrophoneAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Needed"
        alert.informativeText = "Please enable microphone access in System Preferences > Privacy & Security > Microphone."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

}


