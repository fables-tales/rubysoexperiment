#!/usr/bin/env ruby
require "mkmf"

$LDFLAGS << " -Ltarget/debug -lfoo "

# preparation for compilation goes here
create_makefile("foo")
