import intsets

import protobuf/gen
import protobuf/protobuf

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
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "minor",
                number: 2,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "patch",
                number: 3,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "suffix",
                number: 4,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false,
                oneofIdx: -1,
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
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "parameter",
                number: 2,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "proto_file",
                number: 15,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "FileDescriptorProto",
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "compiler_version",
                number: 3,
                ftype: FieldType.Message,
                label: FieldLabel.Optional,
                typeName: "Version",
                packed: false,
                oneofIdx: -1,
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
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "file",
                number: 15,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "CodeGeneratorResponse_File",
                packed: false,
                oneofIdx: -1,
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
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "insertion_point",
                number: 2,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false,
                oneofIdx: -1,
            ),
            FieldDesc(
                name: "content",
                number: 15,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false,
                oneofIdx: -1,
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
