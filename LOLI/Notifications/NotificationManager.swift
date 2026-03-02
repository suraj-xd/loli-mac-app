import UserNotifications

class NotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func sendTimerComplete(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "LOLI"
        content.body = "Focus session complete! \(minutes) min of great work."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
