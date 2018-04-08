# Building

    $ nimpb_build -I. --out=. test_messages_proto3.proto
    $ nimpb_build -I. --out=. conformance.proto
    $ nim c conformance_nim.nim

# Running conformance tests

First you need to get protobuf library sources and build the library. After
building, there should be `conformance/conformance-test-runner` that contains
the actual test suite. The test runner communicates with the `conformance_nim`
over pipes, passing in requests and receiving responses.

Running the test suite (assuming your working directory is in
`protobuf-src/conformance`):

    $ ./conformance-test-runner /path/to/nimpb/tests/conformance/conformance_nim
