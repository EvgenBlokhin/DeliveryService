//
//  DictionaryEncodable.swift
//  Nesicofe
//
//  Created by dev on 29/10/2025.
//

struct DictionaryEncodable: Encodable {
    private let dictionary: [String: Any]

    init(_ dictionary: [String: Any]) {
        self.dictionary = dictionary
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        for (key, value) in dictionary {
            let codingKey = DynamicCodingKeys(stringValue: key)!
            switch value {
            case let v as String: try container.encode(v, forKey: codingKey)
            case let v as Int: try container.encode(v, forKey: codingKey)
            case let v as Bool: try container.encode(v, forKey: codingKey)
            default:
                // можно расширить при необходимости
                break
            }
        }
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}
