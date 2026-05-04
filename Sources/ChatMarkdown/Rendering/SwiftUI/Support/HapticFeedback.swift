import Foundation
#if os(iOS)
import UIKit
#endif

enum HapticFeedback {
    static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}
