# Mem Map

> An optimized Solidity implementation of an in-memory hash map.

Like hashmaps in traditional languages the average lookup and modification time complexity is
$O(1)$. Performance degrades as the mapping reaches its capacity. Performance of the hash map also
depends on the quality of the key derivation algorithm.

## Basic Usage

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {MemMap, MemMapLib} from "mem-map/src/MemMapLib.sol";

contract MyContract {
    function main() public {
        // Allocate with a bit size of 8 (capacity = 2^8 = 256).
        MemMap map = MemMapLib.alloc(8);

        // Set a key in the map to a value (you are respoonsible for derivation, needs to non-zero).
        bytes32 key = keccak256("wow");
        map.set(key, 34);

        // Retrieve value at key.
        uint256 value = map.get(key);

        // Retrieve default value for uninitialized key (0).
        bytes32 uninitializedKey = keccak256("lmao");
        uint256 defaultValue = map.get(uninitializedKey);
        assert(defaultValue == 0);
    }
}
```

### Pair Pointers

In cases where lookups are rare but reading and writing to a specific key-value pair is frequent you
can do a single lookup to retrieve a "pair pointer" which will allow you to read/write the value of
a given pair without having to do further lookups:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import {MemMap, MemMapLib, mapPairPtr} from "mem-map/src/MemMapLib.sol";

contract MyContract {
    function main() public {
        // Allocate with a bit size of 8 (capacity = 2^8 = 256).
        MemMap map = MemMapLib.alloc(8);

        // Retrieve pair pointer.
        bytes32 key = keccak256("wow");
        (mapPairPtr ptr,) = map.getPairPtr(key);

        // Retrieve value at `key` using the pointer.
        uint256 value = ptr.get();

        // Efficiently update the mapping value via the pointer.
        ptr.set(value + 1);
    }
}
```
