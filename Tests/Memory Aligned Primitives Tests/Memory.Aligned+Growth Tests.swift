// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Index_Primitives
import Memory_Aligned_Primitives_Test_Support
import Testing

// Growth behavior folded onto Memory.Aligned (Cleave-8 item A — Memory.Unbounded dissolved).
@Suite("Memory.Aligned Growth Tests")
struct `Memory.Aligned Growth Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Memory.Aligned Growth Tests`.Unit {
    @Test
    func `creates with initial capacity and grows on demand`() throws {
        var region = try Memory.Aligned(byteCount: 8, alignment: try Memory.Alignment(8))
        #expect(region.count >= Index<Byte>.Count(8))
        try region.ensureCapacity(minimum: 64)
        #expect(region.count >= Index<Byte>.Count(64))
    }

    @Test
    func `round-trips bytes through mutable access after growth`() throws {
        var region = try Memory.Aligned(byteCount: 4, alignment: try Memory.Alignment(8))
        try region.ensureCapacity(minimum: 16)
        unsafe region.withUnsafeMutableBytes { bytes in
            unsafe bytes[15] = 0xAB
        }
        unsafe region.withUnsafeBytes { bytes in
            #expect(unsafe bytes[15] == 0xAB)
        }
    }

    @Test
    func `preserves existing bytes across growth`() throws {
        var region = try Memory.Aligned.zeroed(byteCount: 4, alignment: try Memory.Alignment(8))
        unsafe region.withUnsafeMutableBytes { bytes in
            for i in 0..<4 { unsafe bytes[i] = UInt8(i + 1) }
        }
        try region.ensureCapacity(minimum: 32)
        #expect(region.count >= Index<Byte>.Count(32))
        unsafe region.withUnsafeBytes { bytes in
            for i in 0..<4 { #expect(unsafe bytes[i] == UInt8(i + 1)) }
        }
    }

    @Test
    func `reserveDiscardingContents grows without preserving`() throws {
        var region = try Memory.Aligned(byteCount: 8, alignment: try Memory.Alignment(8))
        try region.reserveDiscardingContents(minimum: 128)
        #expect(region.count >= Index<Byte>.Count(128))
    }
}
