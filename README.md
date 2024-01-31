# Mem Map

> An optimized Solidity implementation of an in-memory hash map.

Like hashmaps in traditional languages the average lookup and modification time complexity is
$O(1)$. Performance degrades as the mapping reaches its capacity. Performance of the hash map also
depends on the quality of the key derivation algorithm.

Overall the mapping is optimized for setting and getting from initialized non-colliding keys.

## Performance

Measured by [`MemMap.t.sol`](./test/MemMap.t.sol) (`forge test -vv --mt test_gasUsed`).

**Initializing New Maps**

|Desription|Gas Cost|
|----------|--------|
|Initialize map of size 16| 380|
|Initialize map of size 32| 579|
|Initialize map of size 64| 988|
|Initialize map of size 256| 3,780|

**Get & Set**

|Desription|Gas Cost|
|----------|--------|
|`map.get` (initialized, immediate hit)| 153|
|`map.set` (initialized, immediate hit)| 157|
|`map.set` (uninitialized, immediate hit)| 210|


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

### Other Notes
- looking up an uninitialized key with `getPairPtr` will initialize it and reduce the map's capacity
- the map will revert with `MapFull()` if you attempt to initialize a key via `.set` or
    `.getPairPtr` and it no longer has sufficient capacity

## Inner Workings

### Index derivation

The map from the library on its own does not hash or derive keys. It takes the key at face value and
reads `n` bits starting at the 6th bit for its index (mask: `((1 << n) - 1) << 6`) where `n` is the
bit size of the mapping (set at initialization as the paramter to `alloc`).

### Collision Resolution Method

When a new key is initialized and the index collides with another key it'll simply iterate over the
map looking for the next free slot. The key is then stored together with the value at the found
position. Storing the key in the mapping is necessary for subsequent lookups.

This means that every new key consumes the capacity of the map, regardless if there are overlapping
indices. This means that in the worst case, if you have a map with a capacity `x` and you insert
`x` keys the map will have a set/get time complexity of $O(n)$.
