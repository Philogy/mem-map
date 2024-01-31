// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// forgefmt: disable-start
// @dev Packed: (uint64 memptr, uint32 offsetMask)
type MemMap is uint256;
using MemMapLib for MemMap global;

type mapPairPtr is uint256;
using MemMapLib for mapPairPtr global;
/// forgefmt: disable-end

/// @author philogy <https://github.com/philogy>
library MemMapLib {
    error CapacityTooLarge();
    error OutOfCapacity();
    error MapFull();

    uint256 internal constant CAPACITY_MASK = 0xffffffff;
    uint256 internal constant MAP_PAIR_SPACING = 0x40;

    function alloc(uint256 capacityBits) internal pure returns (MemMap map) {
        uint256 capacity_ = 1 << capacityBits;
        if (capacity_ > CAPACITY_MASK) revert CapacityTooLarge();
        /// @solidity memory-safe-assembly
        assembly {
            // Get free memory.
            let ptr := mload(0x40)
            // Store capacity in first word.
            mstore(ptr, capacity_)
            // Allocate memory region.
            let dataOffset := add(ptr, 0x20)
            let sizeBytes := shl(6, capacity_) // Capacity * 0x40 (key, value)
            mstore(0x40, add(dataOffset, sizeBytes))
            // Clear memory.
            calldatacopy(dataOffset, calldatasize(), sizeBytes)
            // Form stack reference.
            let baseOffsetMask := sub(capacity_, 1)
            // Offset by 6-bits equivalent to multiply by 0x40, ensures we're wrapping around the
            // actual offset
            let offsetMask := shl(6, baseOffsetMask)
            map := or(shl(32, ptr), offsetMask)
        }
    }

    function capacity(MemMap map) internal pure returns (uint256 capacity_) {
        /// @solidity memory-safe-assembly
        assembly {
            capacity_ := and(map, CAPACITY_MASK)
        }
    }

    function getPairPtr(MemMap map, bytes32 key) internal pure returns (mapPairPtr pairPtr, bytes32 storedKey) {
        /// @solidity memory-safe-assembly
        assembly {
            let offsetMask := and(map, CAPACITY_MASK)
            let mapPtr := shr(32, map)
            let mapStart := add(mapPtr, 0x40)

            let startOffset := and(key, offsetMask)
            let keyOffset := startOffset
            let keyPtr := add(mapStart, keyOffset)
            storedKey := mload(keyPtr)

            // Optimize for immediate hit keys.
            if iszero(eq(storedKey, key)) {
                switch storedKey
                case 0 {
                    // Safe to decrement without checking because zero stored keys
                    // indicates empty map slots.
                    mstore(mapPtr, sub(mload(mapPtr), 1))
                    mstore(keyPtr, key)
                }
                default {
                    // Search for key, best case: O(1), worst case: O(n).
                    for {} 1 {} {
                        keyOffset := and(add(keyOffset, MAP_PAIR_SPACING), offsetMask)
                        keyPtr := add(mapStart, keyOffset)
                        storedKey := mload(keyPtr)
                        if eq(storedKey, key) { break }
                        if iszero(storedKey) {
                            // Safe to decrement without checking because zero stored keys
                            // indicates empty map slots.
                            mstore(mapPtr, sub(mload(mapPtr), 1))
                            mstore(keyPtr, key)
                            break
                        }
                        // Check if we wrapped around all the way to the start.
                        if eq(keyOffset, startOffset) {
                            mstore(0x00, 0xda4685ce /* MapFull() */ )
                            revert(0x1c, 0x04)
                        }
                    }
                }
            }

            pairPtr := sub(keyPtr, 0x20)
        }
    }

    function set(MemMap map, bytes32 key, uint256 value) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            let offsetMask := and(map, CAPACITY_MASK)
            let mapPtr := shr(32, map)
            let mapStart := add(mapPtr, 0x40)

            let startOffset := and(key, offsetMask)
            let keyOffset := startOffset
            let keyPtr := add(mapStart, keyOffset)
            let storedKey := mload(keyPtr)

            // Optimize for immediate hit keys.
            if iszero(eq(storedKey, key)) {
                switch storedKey
                case 0 {
                    // Safe to decrement without checking because zero stored keys
                    // indicates empty map slots.
                    mstore(mapPtr, sub(mload(mapPtr), 1))
                    mstore(keyPtr, key)
                }
                default {
                    // Search for key, best case: O(1), worst case: O(n).
                    for {} 1 {} {
                        keyOffset := and(add(keyOffset, MAP_PAIR_SPACING), offsetMask)
                        keyPtr := add(mapStart, keyOffset)
                        storedKey := mload(keyPtr)
                        if eq(storedKey, key) { break }
                        if iszero(storedKey) {
                            // Safe to decrement without checking because zero stored keys
                            // indicates empty map slots.
                            mstore(mapPtr, sub(mload(mapPtr), 1))
                            mstore(keyPtr, key)
                            break
                        }
                        // Check if we wrapped around all the way to the start.
                        if eq(keyOffset, startOffset) {
                            mstore(0x00, 0xda4685ce /* MapFull() */ )
                            revert(0x1c, 0x04)
                        }
                    }
                }
            }

            mstore(sub(keyPtr, 0x20), value)
        }
    }

    function get(MemMap map, bytes32 key) internal pure returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            let offsetMask := and(map, CAPACITY_MASK)
            let mapStart := add(shr(32, map), 0x40)

            let startOffset := and(key, offsetMask)
            let keyOffset := startOffset
            let keyPtr := add(mapStart, keyOffset)
            let storedKey := mload(keyPtr)

            // Optimize for immediate hit keys.
            if iszero(eq(storedKey, key)) {
                if storedKey {
                    for {} 1 {} {
                        keyOffset := and(add(keyOffset, MAP_PAIR_SPACING), offsetMask)
                        keyPtr := add(mapStart, keyOffset)
                        storedKey := mload(keyPtr)
                        if eq(storedKey, key) { break }
                        if iszero(storedKey) { break }
                        // Check if we wrapped around all the way to the start.
                        if eq(keyOffset, startOffset) {
                            mstore(0x00, 0xda4685ce /* MapFull() */ )
                            revert(0x1c, 0x04)
                        }
                    }
                }
            }

            value := mload(sub(keyPtr, 0x20))
        }
    }

    function isNull(MemMap map, bytes32 key) internal pure returns (bool) {
        (, bytes32 storedKey) = map.getPairPtr(key);
        return storedKey == bytes32(0);
    }

    function set(mapPairPtr pairPtr, uint256 value) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(pairPtr, value)
        }
    }

    function get(mapPairPtr pairPtr) internal pure returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := mload(pairPtr)
        }
    }
}
