local enum = require "lib/enum"

CHANNEL_COUNT = 4
PROTOCOL_VERSION = 0

DISCONNECT = enum {
    "EXITING",
    "INCOMPATIBLE",
    "INVALID_PACKET",
    "NAME"
}

EVENT = enum {
    "HELLO",
    "ENTITY_ADD",
    "ENTITY_REMOVE",
    "ENTITY_UPDATE",
    "ENTITY_CONTROL",
    "WORLD",
    "MOVE_TO",
    "BASIC_ATTACK",
    "USE_ABILITY"
}

PACK_TYPE = enum {
    "INITIAL",
    "GENERIC",
    "MOVE_ANIM"
}
