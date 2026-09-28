/// An SA2 seed/key script.
///
/// SA2 is the seed/key mechanism used to authorize test and flashing tools with
/// Volkswagen Auto Group control units. The script is shipped inside the FRF or
/// ODX flash container and is executed by a small bytecode machine that
/// transforms the seed sent by the control unit into the matching key.
///
/// ```swift
/// let script = SA2Script([
///     0x68, 0x02, 0x81, 0x49, 0x93, 0xA5, 0x5A, 0x55, 0xAA, 0x4A, 0x05, 0x87, 0x81, 0x05, 0x95,
///     0x26, 0x68, 0x05, 0x82, 0x49, 0x84, 0x5A, 0xA5, 0xAA, 0x55, 0x87, 0x03, 0xF7, 0x80, 0x6A, 0x4C,
/// ])
/// let key = try script.key(forSeed: 0x1A1B_1C1D) // 0x6A37F02E
/// ```
public struct SA2Script: Hashable, Sendable {
    /// The raw bytecode of the script.
    public let bytes: [UInt8]

    /// Creates a script from its raw bytecode.
    public init(_ bytes: some Sequence<UInt8>) {
        self.bytes = Array(bytes)
    }

    /// Creates a script from a sequence of instructions.
    public init(instructions: some Sequence<SA2Instruction>) {
        self.bytes = instructions.flatMap(\.bytes)
    }

    /// Decodes the bytecode into a linear list of instructions.
    ///
    /// - Throws: ``SA2Error`` if the bytecode contains an unknown opcode or ends
    ///   in the middle of an instruction.
    public func instructions() throws(SA2Error) -> [SA2Instruction] {
        var instructions: [SA2Instruction] = []
        var offset = bytes.startIndex
        while offset < bytes.endIndex {
            let instruction = try SA2Instruction(decoding: bytes, at: offset)
            instructions.append(instruction)
            offset += instruction.size
        }
        return instructions
    }

    /// Runs the script on `seed` and returns the computed key.
    ///
    /// - Throws: ``SA2Error`` if the script is malformed.
    public func key(forSeed seed: UInt32) throws(SA2Error) -> UInt32 {
        var machine = Machine(register: seed)
        while machine.instructionPointer < bytes.endIndex {
            let instruction = try SA2Instruction(decoding: bytes, at: machine.instructionPointer)
            try machine.execute(instruction)
        }
        return machine.register
    }
}

extension SA2Script: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: UInt8...) {
        self.init(elements)
    }
}

extension SA2Script {
    /// A human-readable disassembly of the script, one instruction per line.
    ///
    /// - Throws: ``SA2Error`` if the bytecode cannot be decoded.
    public func disassembly() throws(SA2Error) -> String {
        try instructions().map(\.description).joined(separator: "\n")
    }
}

// MARK: - Machine

extension SA2Script {
    /// The state of the bytecode machine while a script is being executed.
    struct Machine {
        private struct Loop {
            let bodyStart: Int
            var remainingIterations: Int
        }

        var register: UInt32
        private(set) var carry = false
        private(set) var instructionPointer = 0
        private var loops: [Loop] = []

        init(register: UInt32) {
            self.register = register
        }

        mutating func execute(_ instruction: SA2Instruction) throws(SA2Error) {
            let nextInstruction = instructionPointer + instruction.size

            switch instruction {
            case .rotateLeft:
                carry = register & 0x8000_0000 != 0
                register = register << 1 | register >> 31

            case .rotateRight:
                carry = register & 0x1 != 0
                register = register >> 1 | register << 31

            case let .add(operand):
                (register, carry) = register.addingReportingOverflow(operand)

            case let .subtract(operand):
                (register, carry) = register.subtractingReportingOverflow(operand)

            case let .exclusiveOr(operand):
                register ^= operand

            case let .loop(count):
                loops.append(Loop(bodyStart: nextInstruction, remainingIterations: Int(count) - 1))

            case .next:
                guard var loop = loops.popLast() else {
                    throw .unmatchedNext(offset: instructionPointer)
                }
                if loop.remainingIterations > 0 {
                    loop.remainingIterations -= 1
                    loops.append(loop)
                    instructionPointer = loop.bodyStart
                    return
                }

            case let .branchIfCarryClear(offset):
                if !carry {
                    instructionPointer = nextInstruction + Int(offset)
                    return
                }

            case let .branch(offset):
                instructionPointer = nextInstruction + Int(offset)
                return

            case .finish:
                break
            }

            instructionPointer = nextInstruction
        }
    }
}
