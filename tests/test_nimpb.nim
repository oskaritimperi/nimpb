import unittest

import nimpb/nimpb

test "zigzag encode 32bit":
    assert zigzagEncode(int32(0)) == uint32(0)
    assert zigzagEncode(int32(-1)) == uint32(1)
    assert zigzagEncode(int32(1)) == uint32(2)
    assert zigzagEncode(int32(-2)) == uint32(3)
    assert zigzagEncode(int32(2)) == uint32(4)
    assert zigzagEncode(int32(2147483647)) == uint32(4294967294)
    assert zigzagEncode(int32(-2147483648)) == uint32(4294967295)

test "zigzag decode 32bit":
    assert zigzagDecode(uint32(0)) == int32(0)
    assert zigzagDecode(uint32(1)) == int32(-1)
    assert zigzagDecode(uint32(2)) == int32(1)
    assert zigzagDecode(uint32(3)) == int32(-2)
    assert zigzagDecode(uint32(4)) == int32(2)
    assert zigzagDecode(uint32(4294967294)) == int32(2147483647)
    assert zigzagDecode(uint32(4294967295)) == int32(-2147483648)

test "zigzag encode 64bit":
    assert zigzagEncode(int64(0)) == uint64(0)
    assert zigzagEncode(int64(-1)) == uint64(1)
    assert zigzagEncode(int64(1)) == uint64(2)
    assert zigzagEncode(int64(-2)) == uint64(3)
    assert zigzagEncode(int64(2)) == uint64(4)
    assert zigzagEncode(9223372036854775807'i64) == 18446744073709551614'u64
    assert zigzagEncode(-9223372036854775807'i64 - 1'i64) == 18446744073709551615'u64

test "zigzag decode 64bit":
    assert zigzagDecode(uint64(0)) == int64(0)
    assert zigzagDecode(uint64(1)) == int64(-1)
    assert zigzagDecode(uint64(2)) == int64(1)
    assert zigzagDecode(uint64(3)) == int64(-2)
    assert zigzagDecode(uint64(4)) == int64(2)
    assert zigzagDecode(18446744073709551614'u64) == 9223372036854775807'i64
    assert zigzagDecode(18446744073709551615'u64) == -9223372036854775807'i64 - 1'i64
