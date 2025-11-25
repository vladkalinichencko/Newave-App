//
//  LocalNetworkAuthorizer.swift
//  New Wave
//
//  Ensures the iOS local network permission prompt is triggered.
//

import Foundation
import Network
import UIKit

final class LocalNetworkAuthorizer {
    static let shared = LocalNetworkAuthorizer()
    private var browser: NWBrowser?
    private var hasRequested = false

    private init() {}

    /// Triggers the local network permission prompt if it hasn't appeared yet.
    /// If the user previously denied, provides a quick link to Settings.
    func requestAuthorizationIfNeeded(from presenter: UIViewController?) {
        guard !hasRequested else { return }
        hasRequested = true

        // Start a short-lived Bonjour browse; this triggers the system prompt
        // when NSLocalNetworkUsageDescription and NSBonjourServices are present.
        let parameters = NWParameters.tcp
        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: parameters)
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                print("LocalNetworkAuthorizer browser failed: \(error)")
                self?.browser?.cancel()
                self?.browser = nil
                self?.presentSettingsAlertIfNeeded(from: presenter)
            default:
                break
            }
        }

        browser.start(queue: .main)

        // Stop after a short window; prompt will already have been shown if needed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.browser?.cancel()
            self?.browser = nil
        }
    }

    private func presentSettingsAlertIfNeeded(from presenter: UIViewController?) {
        guard let presenter = presenter else { return }
        let alert = UIAlertController(
            title: "Allow Local Network",
            message: "Enable local network access for New Wave to reach the server on your Mac. Go to Settings → Privacy → Local Network and toggle New Wave.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presenter.present(alert, animated: true)
    }
}
