import intsets

import protobuf/types
import protobuf/gen
import protobuf/stream

const
    FileDescriptorSetDesc = MessageDesc(
        name: "FileDescriptorSet",
        fields: @[
            FieldDesc(
                name: "files",
                number: 1,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "FileDescriptorProto",
                packed: false
            )
        ]
    )

    FileDescriptorProtoDesc = MessageDesc(
        name: "FileDescriptorProto",
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
                name: "package",
                number: 2,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "dependency",
                number: 3,
                ftype: FieldType.String,
                label: FieldLabel.Repeated,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "message_type",
                number: 4,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "DescriptorProto",
                packed: false
            ),
            FieldDesc(
                name: "enum_type",
                number: 5,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "EnumDescriptorProto",
                packed: false
            ),
        ]
    )

    DescriptorProtoDesc = MessageDesc(
        name: "DescriptorProto",
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
                name: "field",
                number: 2,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "FieldDescriptorProto",
                packed: false
            ),
            FieldDesc(
                name: "nested_type",
                number: 3,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "DescriptorProto",
                packed: false
            ),
            FieldDesc(
                name: "enum_type",
                number: 4,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "EnumDescriptorProto",
                packed: false
            ),
        ]
    )

    EnumDescriptorProtoDesc = MessageDesc(
        name: "EnumDescriptorProto",
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
                name: "value",
                number: 2,
                ftype: FieldType.Message,
                label: FieldLabel.Repeated,
                typeName: "EnumValueDescriptorProto",
                packed: false
            ),
        ]
    )

    EnumValueDescriptorProtoDesc = MessageDesc(
        name: "EnumValueDescriptorProto",
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
                name: "number",
                number: 2,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
        ]
    )

    FieldDescriptorProtoDesc = MessageDesc(
        name: "FieldDescriptorProto",
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
                name: "number",
                number: 3,
                ftype: FieldType.Int32,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "label",
                number: 4,
                ftype: FieldType.Enum,
                label: FieldLabel.Optional,
                typeName: "FieldDescriptorProto_Label",
                packed: false
            ),
            FieldDesc(
                name: "type",
                number: 5,
                ftype: FieldType.Enum,
                label: FieldLabel.Optional,
                typeName: "FieldDescriptorProto_Type",
                packed: false
            ),
            FieldDesc(
                name: "type_name",
                number: 6,
                ftype: FieldType.String,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
            FieldDesc(
                name: "options",
                number: 8,
                ftype: FieldType.Message,
                label: FieldLabel.Optional,
                typeName: "FieldOptions",
                packed: false
            ),
        ]
    )

    FieldDescriptorProto_LabelDesc = EnumDesc(
        name: "FieldDescriptorProto_Label",
        values: @[
            EnumValueDesc(name: "LABEL_OPTIONAL", number: 1),
            EnumValueDesc(name: "LABEL_REQUIRED", number: 2),
            EnumValueDesc(name: "LABEL_REPEATED", number: 3)
        ]
    )

    FieldDescriptorProto_TypeDesc = EnumDesc(
        name: "FieldDescriptorProto_Type",
        values: @[
            EnumValueDesc(name: "TYPE_DOUBLE", number: 1),
            EnumValueDesc(name: "TYPE_FLOAT", number: 2),
            EnumValueDesc(name: "TYPE_INT64", number: 3),
            EnumValueDesc(name: "TYPE_UINT64", number: 4),
            EnumValueDesc(name: "TYPE_INT32", number: 5),
            EnumValueDesc(name: "TYPE_FIXED64", number: 6),
            EnumValueDesc(name: "TYPE_FIXED32", number: 7),
            EnumValueDesc(name: "TYPE_BOOL", number: 8),
            EnumValueDesc(name: "TYPE_STRING", number: 9),
            EnumValueDesc(name: "TYPE_GROUP", number: 10),
            EnumValueDesc(name: "TYPE_MESSAGE", number: 11),
            EnumValueDesc(name: "TYPE_BYTES", number: 12),
            EnumValueDesc(name: "TYPE_UINT32", number: 13),
            EnumValueDesc(name: "TYPE_ENUM", number: 14),
            EnumValueDesc(name: "TYPE_SFIXED32", number: 15),
            EnumValueDesc(name: "TYPE_SFIXED64", number: 16),
            EnumValueDesc(name: "TYPE_SINT32", number: 17),
            EnumValueDesc(name: "TYPE_SINT64", number: 18),
        ]
    )

    FieldOptionsDesc = MessageDesc(
        name: "FieldOptions",
        fields: @[
            FieldDesc(
                name: "packed",
                number: 2,
                ftype: FieldType.Bool,
                label: FieldLabel.Optional,
                typeName: "",
                packed: false
            ),
        ]
    )

generateEnumType(FieldDescriptorProto_LabelDesc)
generateEnumProcs(FieldDescriptorProto_LabelDesc)

generateEnumType(FieldDescriptorProto_TypeDesc)
generateEnumProcs(FieldDescriptorProto_TypeDesc)

generateMessageType(EnumValueDescriptorProtoDesc)
generateMessageProcs(EnumValueDescriptorProtoDesc)

generateMessageType(EnumDescriptorProtoDesc)
generateMessageProcs(EnumDescriptorProtoDesc)

generateMessageType(FieldOptionsDesc)
generateMessageProcs(FieldOptionsDesc)

generateMessageType(FieldDescriptorProtoDesc)
generateMessageProcs(FieldDescriptorProtoDesc)

generateMessageType(DescriptorProtoDesc)
generateMessageProcs(DescriptorProtoDesc)

generateMessageType(FileDescriptorProtoDesc)
generateMessageProcs(FileDescriptorProtoDesc)

generateMessageType(FileDescriptorSetDesc)
generateMessageProcs(FileDescriptorSetDesc)
