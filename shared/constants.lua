local enum = require "lib/enum"

CHANNEL_COUNT = 4
PROTOCOL_VERSION = 0

DISCONNECT = enum {
    "INCOMPATIBLE",
    "NAME",
    "FULL",
    "EXITING",
    "INVALID_PACKET"
}

EVENT = enum {
    "HELLO",
    "MOVE_TO"
}
