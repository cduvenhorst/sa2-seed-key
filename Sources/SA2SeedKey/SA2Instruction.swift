/// A single decoded instruction of the SA2 bytecode machine.
///
/// Every instruction starts with a one-byte opcode, optionally followed by
/// operand bytes. 32-bit operands are stored big-endian.
public enum SA2Instruction: Hashable, Sendable {
    /// `0x81` – Rotates the register one bit to the left. The bit rotated out
    /// becomes the carry flag.
    case rotateLeft
    /// `0x82` – Rotates the register one bit to the right. The bit rotated out
    /// becomes the carry flag.
    case rotateRight
    /// `0x93` – Adds the operand to the register. Sets the carry flag on overflow.
    case add(UInt32)
    /// `0x84` – Subtracts the operand from the register. Sets the carry flag on underflow.
    case subtract(UInt32)
    /// `0x87` – XORs the operand into the register.
    case exclusiveOr(UInt32)
    /// `0x68` – Starts a loop whose body runs `count` times.
    case loop(count: UInt8)
    /// `0x49` – Marks the end of the innermost loop body.
    case next
    /// `0x4A` – Skips `offset` bytes if the carry flag is clear.
    case branchIfCarryClear(offset: UInt8)
    /// `0x6B` – Unconditionally skips `offset` bytes.
    case branch(offset: UInt8)
    /// `0x4C` – Marks the end of the script. It does not halt the machine;
    /// execution simply continues with the following byte, if any.
    case finish

    /// The raw opcode byte of the instruction.
    public var opcode: UInt8 {
        switch self {
        case .rotateLeft: 0x81
        case .rotateRight: 0x82
        case .add: 0x93
        case .subtract: 0x84
        case .exclusiveOr: 0x87
        case .loop: 0x68
        case .next: 0x49
        case .branchIfCarryClear: 0x4A
        case .branch: 0x6B
        case .finish: 0x4C
        }
    }

    /// The encoded size of the instruction in bytes, including the opcode.
    public var size: Int {
        switch self {
        case .rotateLeft, .rotateRight, .next, .finish: 1
        case .loop, .branchIfCarryClear, .branch: 2
        case .add, .subtract, .exclusiveOr: 5
        }
    }

    /// The encoded bytes of the instruction.
    public var bytes: [UInt8] {
        switch self {
        case .rotateLeft, .rotateRight, .next, .finish:
            [opcode]
        case let .loop(operand), let .branchIfCarryClear(operand), let .branch(operand):
            [opcode, operand]
        case let .add(operand), let .subtract(operand), let .exclusiveOr(operand):
            [opcode] + withUnsafeBytes(of: operand.bigEndian, Array.init)
        }
    }
}

extension SA2Instruction {
    /// Decodes the instruction starting at `offset` in `bytes`.
    ///
    /// `offset` is counted from the start of `bytes` and must not be negative.
    ///
    /// - Throws: ``SA2Error/unknownOpcode(_:offset:)`` if the byte at `offset`
    ///   is not a valid opcode, or ``SA2Error/truncatedInstruction(opcode:offset:)``
    ///   if the operands extend past the end of `bytes`.
    public init(decoding bytes: some Collection<UInt8>, at offset: Int) throws(SA2Error) {
        precondition(offset >= 0, "Offset must not be negative")
        let bytes = Array(bytes.dropFirst(offset).prefix(5))
        guard let opcode = bytes.first else {
            throw .truncatedInstruction(opcode: nil, offset: offset)
        }

        func operand8() throws(SA2Error) -> UInt8 {
            guard bytes.count >= 2 else { throw .truncatedInstruction(opcode: opcode, offset: offset) }
            return bytes[1]
        }

        func operand32() throws(SA2Error) -> UInt32 {
            guard bytes.count >= 5 else { throw .truncatedInstruction(opcode: opcode, offset: offset) }
            return bytes[1...4].reduce(0) { $0 << 8 | UInt32($1) }
        }

        switch opcode {
        case 0x81: self = .rotateLeft
        case 0x82: self = .rotateRight
        case 0x93: self = try .add(operand32())
        case 0x84: self = try .subtract(operand32())
        case 0x87: self = try .exclusiveOr(operand32())
        case 0x68: self = try .loop(count: operand8())
        case 0x49: self = .next
        case 0x4A: self = try .branchIfCarryClear(offset: operand8())
        case 0x6B: self = try .branch(offset: operand8())
        case 0x4C: self = .finish
        default: throw .unknownOpcode(opcode, offset: offset)
        }
    }
}

extension SA2Instruction: CustomStringConvertible {
    public var description: String {
        switch self {
        case .rotateLeft: "rsl"
        case .rotateRight: "rsr"
        case let .add(value): "add \(value.hex)"
        case let .subtract(value): "sub \(value.hex)"
        case let .exclusiveOr(value): "eor \(value.hex)"
        case let .loop(count): "for \(count)"
        case .next: "next"
        case let .branchIfCarryClear(offset): "bcc +\(offset)"
        case let .branch(offset): "bra +\(offset)"
        case .finish: "finish"
        }
    }
}

extension UInt32 {
    var hex: String {
        let digits = String(self, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: 8 - digits.count) + digits
    }
}
