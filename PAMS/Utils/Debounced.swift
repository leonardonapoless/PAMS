//
//  Debounced.swift
//  PAMS
//
//  Created by Leonardo Nápoles on 10/25/25.
//

import SwiftUI
import Combine

// a property wrapper that debounces a value
// this is useful for delaying a search query until the user has stopped typing
@propertyWrapper
public struct Debounced<Value>: DynamicProperty {
    @StateObject private var debouncer: Debouncer<Value>

    public init(wrappedValue: Value, delay: TimeInterval) {
        _debouncer = StateObject(wrappedValue: Debouncer(initialValue: wrappedValue, delay: delay))
    }

    public var wrappedValue: Value {
        get { debouncer.currentValue }
        nonmutating set { debouncer.update(newValue) }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

private final class Debouncer<Value>: ObservableObject {
    @Published var currentValue: Value
    private let subject = PassthroughSubject<Value, Never>()
    private var cancellable: AnyCancellable?

    init(initialValue: Value, delay: TimeInterval) {
        self.currentValue = initialValue
        cancellable = subject
            .debounce(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] in self?.currentValue = $0 }
    }

    func update(_ value: Value) {
        subject.send(value)
    }
}
