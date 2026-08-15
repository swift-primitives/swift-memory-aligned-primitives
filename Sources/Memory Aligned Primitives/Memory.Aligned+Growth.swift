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
public import Byte_Primitives
public import Growth_Primitives
public import Index_Primitives
public import Memory_Alignment_Primitives
import Ordinal_Primitives_Standard_Library_Integration

// MARK: - Growth.Growable (the growth sub-axis realized as a leaf capability — calculus §5.3)

/// `Memory.Aligned` is a growable leaf that can reallocate its single backing region to a larger capacity in place.
///
/// Per the placement calculus, growth-ability is a leaf capability signalled by conformance presence;
/// the growth *rate* is carried separately by the leaf's ``Memory/Aligned/growthPolicy``.
extension Memory.Aligned: Growth.Growable {}

// MARK: - Capacity Management (grow-in-place)

extension Memory.Aligned {
    /// Ensures the region has at least the specified capacity, preserving existing bytes.
    ///
    /// If the current capacity is sufficient, this is a no-op. If growth is needed,
    /// bytes in `[0..<min(oldCapacity, newCapacity)]` are preserved.
    ///
    /// - Parameter minimum: The minimum required capacity.
    /// - Throws: `Memory.Aligned.Error` if reallocation fails.
    /// - Complexity: O(n) when reallocation occurs, O(1) otherwise.
    @inlinable
    public mutating func ensureCapacity(
        minimum: Index<Byte>.Count
    ) throws(Self.Error) {
        guard minimum > count else { return }

        try reallocate(
            to: Index<Byte>.Count.max(growthPolicy.capacity(from: count), minimum),
            preserving: true
        )
    }

    /// Ensures the region has at least the specified capacity without bounds checking.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter.
    ///   - minimum: The minimum required capacity.
    /// - Precondition: Reallocation must succeed.
    @inlinable
    public mutating func ensureCapacity(
        __unchecked: Void = (),
        minimum: Index<Byte>.Count
    ) {
        guard minimum > count else { return }

        do {
            try reallocate(
                to: Index<Byte>.Count.max(growthPolicy.capacity(from: count), minimum),
                preserving: true
            )
        } catch {
            preconditionFailure("Aligned region reallocation failed: \(error)")
        }
    }

    /// Reserves capacity without preserving existing contents.
    ///
    /// Faster than `ensureCapacity` when the existing data is not needed. Use this when
    /// the entire region is about to be overwritten.
    ///
    /// - Parameter minimum: The minimum required capacity.
    /// - Throws: `Memory.Aligned.Error` if reallocation fails.
    /// - Complexity: O(1) for the copy (no data preserved).
    @inlinable
    public mutating func reserveDiscardingContents(
        minimum: Index<Byte>.Count
    ) throws(Self.Error) {
        guard minimum > count else { return }

        try reallocate(
            to: Index<Byte>.Count.max(growthPolicy.capacity(from: count), minimum),
            preserving: false
        )
    }

    /// Reallocates the backing region to `newCapacity`, optionally preserving the prefix.
    ///
    /// Allocates a fresh aligned region, copies `[0, min(count, newCapacity))` when
    /// `preserving`, then move-assigns it into `self` — the old region's `deinit`
    /// deallocates the previous backing (single-free; no double-free).
    @usableFromInline
    internal mutating func reallocate(
        to newCapacity: Index<Byte>.Count,
        preserving: Bool
    ) throws(Self.Error) {
        var newRegion = try Memory.Aligned(
            byteCount: newCapacity,
            alignment: alignment,
            growthPolicy: growthPolicy
        )

        if preserving {
            let bytesToCopy = Int(bitPattern: Index<Byte>.Count.min(count, newCapacity).underlying.rawValue)
            unsafe newRegion.withUnsafeMutableBytes { dest in
                unsafe withUnsafeBytes { src in
                    unsafe dest.copyMemory(
                        from: UnsafeRawBufferPointer(rebasing: src.prefix(bytesToCopy))
                    )
                }
            }
        }

        self = newRegion
    }
}
