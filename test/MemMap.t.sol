// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MemMap, MemMapLib, mapPairPtr} from "../src/MemMapLib.sol";

/// @author philogy <https://github.com/philogy>
contract MemMapTest is Test {
    function test_bruh() public {
        test_fuzzingSingleSetAndGet(bytes32(0), 0x0100000000000000000000000000000000000000000000000000000000000000, 1);
    }

    function test_fuzzingSingleSetAndGet(bytes32 seed, bytes32 key, uint256 value) public {
        vm.assume(key != bytes32(0));
        _brutalize(seed, 16);

        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(3);

        seed = _brutalize(seed, 16);

        assertEq(map.get(key), 0, "incorrect default value");
        map.set(key, value);
        assertEq(map.get(key), value, "value not set");
    }

    function test_fuzzingSetViaPairPtr(bytes32 seed, bytes32 key, uint256 value) public {
        vm.assume(key != bytes32(0));
        _brutalize(seed, 16);

        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(3);

        seed = _brutalize(seed, 16);

        (mapPairPtr ptr, bytes32 storedKey) = map.getPairPtr(key);
        (mapPairPtr refetchedPtr, bytes32 newStoredKey) = map.getPairPtr(key);
        assertEq(mapPairPtr.unwrap(ptr), mapPairPtr.unwrap(refetchedPtr), "refetchedPtr not equal to original pointer");
        assertEq(newStoredKey, key, "Stored key wasn't updated by getPairPtr");
        assertEq(storedKey, bytes32(0), "default stored key not 0");
        ptr.set(value);
        assertEq(ptr.get(), value, "pointer did not return stored value");
        (refetchedPtr, newStoredKey) = map.getPairPtr(key);
        assertEq(
            mapPairPtr.unwrap(ptr),
            mapPairPtr.unwrap(refetchedPtr),
            "refetchedPtr not equal to original pointer after set"
        );
        assertEq(newStoredKey, key, "Stored key incorrect after set");
        assertEq(map.get(key), value, "Direct get returned incorrect value");
    }

    function test_revertsIfSetAndMapFull() public {
        uint256 bits = 2;
        MemMap map = MemMapLib.alloc(bits);

        for (uint256 i = 0; i < (1 << bits); i++) {
            map.set(bytes32(1 << i), i);
        }

        vm.expectRevert(MemMapLib.MapFull.selector);
        map.set("lmao", 34);
    }

    function test_revertsIfGetAndMapFull() public {
        uint256 bits = 2;
        MemMap map = MemMapLib.alloc(bits);

        for (uint256 i = 0; i < (1 << bits); i++) {
            map.set(bytes32(1 << i), i);
        }

        vm.expectRevert(MemMapLib.MapFull.selector);
        map.get("lmao");
    }

    function test_collidingKeys() public {
        bytes32 key1 = bytes32(uint256((1 << 6) + 1));
        uint256 value1 = 34;
        bytes32 key2 = bytes32(uint256((1 << 6) + 2));
        uint256 value2 = 3987;

        MemMap map = MemMapLib.alloc(3);
        map.set(key1, value1);
        vm.breakpoint("c");

        map.set(key2, value2);

        assertEq(map.get(key1), value1);
        assertEq(map.get(key2), value2);
    }

    function test_gasUsed_alloc16() public {
        uint256 g0 = gasleft();
        MemMapLib.alloc(4);
        uint256 g1 = gasleft();
        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_alloc32() public {
        uint256 g0 = gasleft();
        MemMapLib.alloc(5);
        uint256 g1 = gasleft();
        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_alloc64() public {
        uint256 g0 = gasleft();
        MemMapLib.alloc(6);
        uint256 g1 = gasleft();
        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_alloc256() public {
        uint256 g0 = gasleft();
        MemMapLib.alloc(8);
        uint256 g1 = gasleft();
        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_singleSetNull() public {
        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(8);

        bytes32 key = keccak256("key");

        uint256 g0 = gasleft();
        map.set(key, 34);
        uint256 g1 = gasleft();

        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_singleSet() public {
        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(8);

        bytes32 key = keccak256("key");
        map.set(key, 34);

        uint256 g0 = gasleft();
        map.set(key, 21);
        uint256 g1 = gasleft();

        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_singleGet() public {
        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(8);

        bytes32 key = keccak256("key");
        map.set(key, 34);

        uint256 g0 = gasleft();
        map.get(key);
        uint256 g1 = gasleft();

        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_singlePointerGet() public {
        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(8);

        bytes32 key = keccak256("key");
        map.set(key, 34);

        uint256 g0 = gasleft();
        map.getPairPtr(key);
        uint256 g1 = gasleft();

        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_setViaPointer() public {
        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(8);

        bytes32 key = keccak256("key");
        (mapPairPtr ptr,) = map.getPairPtr(key);

        uint256 g0 = gasleft();
        ptr.set(21);
        uint256 g1 = gasleft();

        emit log_named_uint("used", g0 - g1);
    }

    function test_gasUsed_getViaPointer() public {
        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(8);

        bytes32 key = keccak256("key");
        (mapPairPtr ptr,) = map.getPairPtr(key);
        ptr.set(34);

        uint256 g0 = gasleft();
        ptr.get();
        uint256 g1 = gasleft();

        emit log_named_uint("used", g0 - g1);
    }

    function _brutalize(bytes32 seed, uint256 freeWords) internal pure returns (bytes32) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, seed)
            mstore(0x20, not(seed))

            for { let offset := mload(0x40) } lt(offset, mul(freeWords, 0x20)) { offset := add(offset, 0x20) } {
                seed := keccak256(0x00, 0x20)
                mstore(0x00, seed)
                mstore(offset, seed)
            }
        }

        return seed;
    }

    function _hash(bytes32 seed, uint256 i) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let a := mload(0x00)
            let b := mload(0x20)
            mstore(0x00, seed)
            mstore(0x20, i)
            hash := keccak256(0x00, 0x40)
            mstore(0x00, a)
            mstore(0x20, b)
        }
    }
}
