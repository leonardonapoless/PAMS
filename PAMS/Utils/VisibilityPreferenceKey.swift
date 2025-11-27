import SwiftUI

struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Double] = [:]

    static func reduce(value: inout [String: Double], nextValue: () -> [String: Double]) {
        value.merge(nextValue()) { _, new in new }
    }
}
