#!/bin/bash
cargo build
ruby extconf.rb
make
ruby -e '$: << "."; require "foo.so"; puts Foo.return_3'
