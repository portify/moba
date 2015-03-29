#!/bin/sh
love . --server --listen 127.0.0.1:6788 --quit-on-empty &
love . --connect 127.0.0.1:6788
