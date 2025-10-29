//
//  AnyEncodable.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

// AnyEncodable для упаковки произвольного Encodable в payload
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
