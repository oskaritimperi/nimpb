import endians
import json
import streams
import strformat

import nimpb/nimpb

import conformance_pb
import test_messages_proto3_pb

let
    inputStream = newFileStream(stdin)
    outputStream = newFileStream(stdout)

proc readInt32Le(s: Stream): int32 =
    var value = readInt32(s)
    littleEndian32(addr(result), addr(value))

proc writeInt32Le(s: Stream, value: int32) =
    var value = value
    var buf: int32
    littleEndian32(addr(buf), addr(value))
    write(s, buf)

proc myReadString(s: Stream, size: int): string =
    result = newString(size)
    if readData(s, addr(result[0]), size) != size:
        raise newException(Exception, "failed to read data")

proc errorMessage(exc: ref Exception): string =
    result = $exc.name & ": " & exc.msg & "\n" & getStackTrace(exc)

while true:
    var requestSize = 0'i32

    try:
        requestSize = readInt32Le(inputStream)
    except:
        break

    var requestData = myReadString(inputStream, requestSize)

    let request = newConformance_ConformanceRequest(requestData)

    let response = newConformance_ConformanceResponse()

    if request.messageType == "protobuf_test_messages.proto2.TestAllTypesProto2":
        response.skipped = "skipping proto2 tests"
    else:
        try:
            var parsed: protobuf_test_messages_proto3_TestAllTypesProto3

            if hasProtobufPayload(request):
                parsed = newprotobuf_test_messages_proto3_TestAllTypesProto3(request.protobufPayload)
            elif hasJsonPayload(request):
                var j: JsonNode

                try:
                    j = parseJson(request.jsonPayload)
                except Exception as exc:
                    raise newException(JsonParsingError, exc.msg)

                parsed = parseprotobuf_test_messages_proto3_TestAllTypesProto3(j)

            if request.requestedOutputFormat == conformance_WireFormat.PROTOBUF:
                let ser = serialize(parsed)
                response.protobufPayload = cast[seq[byte]](ser)
            elif request.requestedOutputFormat == conformance_WireFormat.JSON:
                response.jsonPayload = $toJson(parsed)
        except IOError as exc:
            response.parse_error = errorMessage(exc)
        except OverflowError as exc:
            response.parseError = errorMessage(exc)
        except nimpb.ParseError as exc:
            response.parse_error = errorMessage(exc)
        except JsonParsingError as exc:
            response.parseError = errorMessage(exc)
        except ValueError as exc:
            response.serializeError = errorMessage(exc)
        except Exception as exc:
            response.runtimeError = errorMessage(exc)

    let responseData = serialize(response)

    writeInt32Le(outputStream, int32(len(responseData)))
    write(outputStream, responseData)

    flush(outputStream)
