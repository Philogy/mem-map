// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MemMap, MemMapLib} from "../src/MemMapLib.sol";

/// @author philogy <https://github.com/philogy>
contract MemMapTest is Test {
    function test_bruh() public {
        test_fuzzingSingleSetAndGet(bytes32(0), 0x0100000000000000000000000000000000000000000000000000000000000000, 1);
    }

    function test_fuzzingSingleSetAndGet(bytes32 seed, bytes32 key, uint256 value) public {
        vm.pauseGasMetering();
        vm.assume(key != bytes32(0));
        _brutalize(seed);

        // 8-bit capacity => 256
        MemMap map = MemMapLib.alloc(3);

        bytes32[10] memory above;
        for (uint256 i = 0; i < 10; i++) {
            above[i] = _hash(seed, i);
        }
        vm.resumeGasMetering();

        vm.breakpoint("a");

        assertEq(map.get(key), 0, "incorrect default value");
        map.set(key, value);
        assertEq(map.get(key), value, "value not set");
    }

    function test_gasUsed_alloc32() public {
        uint256 g0 = gasleft();
        MemMapLib.alloc(5);
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

    function _brutalize(bytes32 seed) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, seed)
            mstore(0x20, not(seed))

            for { let offset := mload(0x40) } lt(offset, mul(16, 0x20)) { offset := add(offset, 0x20) } {
                let nextRand := keccak256(0x00, 0x20)
                mstore(0x00, nextRand)
                mstore(offset, nextRand)
            }
        }
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
