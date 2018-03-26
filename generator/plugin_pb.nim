import intsets

import protobuf/types
import protobuf/gen
import protobuf/stream

import descriptor_pb

const
    VersionDesc = MessageDesc(
        name: "Version",
        fields: @[
            FieldDesc(
                name: "major",
                number: 1,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "minor",
                number: 2,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "patch",
                number: 3,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "suffix",
                number: 4,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            )
        ]
    )

    CodeGeneratorRequestDesc = MessageDesc(
        name: "CodeGeneratorRequest",
        fields: @[
            FieldDesc(
                name: "file_to_generate",
                number: 1,
                ftype: FieldType.String,
                label: FieldLabel.Repeated,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "parameter",
                number: 2,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "proto_file",
                number: 15,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "FileDescriptorProto",
                packed: false
            ),
            FieldDesc(
                name: "compiler_version",
                number: 3,
                ftype: FieldType.Message,
                label: FieldLabel.Optional,
                typeName: "Version",
                packed: false
            )
        ]
    )

    CodeGeneratorResponseDesc = MessageDesc(
        name: "CodeGeneratorResponse",
        fields: @[
            FieldDesc(
                name: "error",
                number: 1,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "file",
                number: 15,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "CodeGeneratorResponse_File",
                packed: false
            ),
        ]
    )

    CodeGeneratorResponse_FileDesc = MessageDesc(
        name: "CodeGeneratorResponse_File",
        fields: @[
            FieldDesc(
                name: "name",
                number: 1,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "insertion_point",
                number: 2,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "content",
                number: 15,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
        ]
    )

generateMessageType(VersionDesc)
generateMessageProcs(VersionDesc)

generateMessageType(CodeGeneratorRequestDesc)
generateMessageProcs(CodeGeneratorRequestDesc)

generateMessageType(CodeGeneratorResponse_FileDesc)
generateMessageProcs(CodeGeneratorResponse_FileDesc)

generateMessageType(CodeGeneratorResponseDesc)
generateMessageProcs(CodeGeneratorResponseDesc)
