import UserNotifications

/// Runs between a push arriving and the system showing it, for payloads that
/// set `mutable-content: 1` — the window to decrypt a body, download an
/// attachment, or rewrite the title. Nothing else triggers it.
///
/// The name is load-bearing: `project.yml` points the extension's
/// `NSExtensionPrincipalClass` at this class, and the system instantiates it
/// by that name. Renaming it here means renaming it there.
class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var mutableContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        mutableContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let mutableContent else {
            // Nothing to modify: deliver what arrived rather than nothing.
            contentHandler(request.content)
            return
        }

        // Change the content here. Work that takes time — a download, a
        // decryption — belongs before this call, not after it.
        contentHandler(mutableContent)
    }

    /// The window is closing and the system is about to deliver whatever it
    /// has. Hand back the best version prepared so far: returning nothing
    /// shows the notification exactly as it arrived, discarding the work.
    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let mutableContent else { return }
        contentHandler(mutableContent)
    }
}
