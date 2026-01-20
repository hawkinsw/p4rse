// The Swift Programming Language
// https://docs.swift.org/swift-book

public enum ValueType {
    case Boolean(Bool)
}

public struct Value {
    public var value_type: ValueType
}

public class Packet {
    public init() {}
}