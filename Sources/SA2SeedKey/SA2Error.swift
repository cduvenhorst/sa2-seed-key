/// Errors thrown while decoding or executing an SA2 script.
public enum SA2Error: Error, Hashable, Sendable {
    /// The byte at `offset` is not a known opcode.
    case unknownOpcode(UInt8, offset: Int)
    /// The instruction at `offset` needs more operand bytes than the script contains.
    /// `opcode` is `nil` if not even the opcode byte is available.
    case truncatedInstruction(opcode: UInt8?, offset: Int)
    /// A `next` instruction at `offset` has no matching `loop` instruction.
    case unmatchedNext(offset: Int)
}

extension SA2Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .unknownOpcode(opcode, offset):
            "Unknown opcode \(opcode.hex) at offset \(offset)"
        case let .truncatedInstruction(opcode?, offset):
            "Instruction \(opcode.hex) at offset \(offset) is truncated"
        case let .truncatedInstruction(nil, offset):
            "Expected an instruction at offset \(offset)"
        case let .unmatchedNext(offset):
            "Instruction `next` at offset \(offset) has no matching loop"
        }
    }
}

extension UInt8 {
    var hex: String {
        let digits = String(self, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: 2 - digits.count) + digits
    }
}
