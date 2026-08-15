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

import Affine_Primitives_Standard_Library_Integration
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration

// MARK: - Single Byte Access

extension Memory.Aligned {
    /// Accesses the byte at the given index.
    ///
    /// - Parameter index: The byte index to access.
    /// - Returns: The byte value at that index.
    ///
    /// - Precondition: `index >= 0 && index < count`
    ///
    /// - Note: For bulk access, prefer `bytes`, `mutableBytes`, or `withUnsafeBytes`.
    ///   Single-byte subscripting is intended for debugging and infrequent access.
    @inlinable
    public subscript(index: Int) -> Byte {
        get {
            precondition(index >= 0 && index < Int(bitPattern: count), "index out of bounds")
            return unsafe bytePointer[index]
        }
        set {
            precondition(index >= 0 && index < Int(bitPattern: count), "index out of bounds")
            unsafe bytePointer[index] = newValue
        }
    }
}

// MARK: - Copy Convenience

extension Memory.Aligned {
    /// Copies bytes from a source span into this buffer at the given offset.
    ///
    /// - Parameters:
    ///   - source: The source span to copy from.
    ///   - offset: The byte offset in this buffer where copying begins. Defaults to 0.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset + source.count <= self.count`
    @inlinable
    public mutating func copy(
        from source: Span<Byte>,
        at offset: Int = 0
    ) {
        precondition(offset >= 0 && offset + source.count <= Int(bitPattern: count))
        unsafe withUnsafeMutableBufferPointer { dest in
            unsafe source.withUnsafeBufferPointer { src in
                guard let destBase = unsafe dest.baseAddress else { return }
                guard let srcBase = unsafe src.baseAddress else { return }
                unsafe destBase.advanced(by: offset)
                    .update(from: srcBase, count: src.count)
            }
        }
    }

    /// Copies bytes from a raw buffer pointer into this buffer at the given offset.
    ///
    /// - Parameters:
    ///   - source: The raw buffer pointer to copy from.
    ///   - offset: The byte offset in this buffer where copying begins. Defaults to 0.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset + source.count <= self.count`
    @inlinable
    public mutating func copy(
        from source: UnsafeRawBufferPointer,
        at offset: Int = 0
    ) {
        precondition(offset >= 0 && offset + source.count <= Int(bitPattern: count))
        unsafe withUnsafeMutableBytes { dest in
            guard let destBase = unsafe dest.baseAddress else { return }
            guard let srcBase = unsafe source.baseAddress else { return }
            unsafe destBase.advanced(by: offset)
                .copyMemory(from: srcBase, byteCount: source.count)
        }
    }
}

// MARK: - Zero Convenience

extension Memory.Aligned {
    /// Zeroes all bytes in this buffer.
    @inlinable
    public mutating func zero() {
        unsafe withUnsafeMutableBytes { buffer in
            _ = unsafe buffer.baseAddress?.initializeMemory(
                as: Byte.self,
                repeating: Byte(0),
                count: buffer.count
            )
        }
    }

    /// Zeroes bytes in the specified range.
    ///
    /// - Parameter range: The range of bytes to zero.
    ///
    /// - Precondition: `range.lowerBound >= 0`
    /// - Precondition: `range.upperBound <= count`
    @inlinable
    public mutating func zero(range: Swift.Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= Int(bitPattern: count))
        unsafe withUnsafeMutableBytes { buffer in
            guard let base = unsafe buffer.baseAddress else { return }
            let start = unsafe base.advanced(by: range.lowerBound)
            unsafe start.initializeMemory(as: Byte.self, repeating: Byte(0), count: range.count)
        }
    }

    /// Zeroes bytes from the given offset to the end of the buffer.
    ///
    /// - Parameter offset: The starting offset from which to zero.
    ///
    /// - Precondition: `offset >= 0`
    /// - Precondition: `offset <= count`
    @inlinable
    public mutating func zero(from offset: Int) {
        let size = Int(bitPattern: count)
        precondition(offset >= 0 && offset <= size)
        zero(range: offset..<size)
    }
}
