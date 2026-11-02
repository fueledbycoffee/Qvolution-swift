// Copyright (c) 2014-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception.
// From swift-foundation dbacc67779dc, Predicate/PredicateExpression.swift.
extension KeyPath {
    package var _unsafeAssumeSendable: KeyPath<Root, Value> & Sendable {
        func _unsafeCast<T, U>(_ t: T) -> U { t as! U }
        return _unsafeCast(self) as KeyPath<Root, Value> & Sendable
    }
}
