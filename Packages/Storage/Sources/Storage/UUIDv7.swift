import Foundation

extension UUID {
    /// Time-ordered UUID (RFC 9562 version 7): 48-bit Unix milliseconds followed by random bits.
    static func v7(date: Date = Date()) -> UUID {
        var bytes = (0..<16).map { _ in UInt8.random(in: .min ... .max) }
        let ms = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        for i in 0..<6 {
            bytes[i] = UInt8(truncatingIfNeeded: ms >> (8 * (5 - i)))
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x70
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
