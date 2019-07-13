# Minimum viable gem-free calling rust from ruby example.

For [Rubyfmt](https://github.com/samphippen) I'm currently looking at rewriting
significant sections in Rust, because there's some performance issues. Broadly
speaking, it turns out that cleaning up a very large Ruby parse tree (e.g. 4000
lines) can be slow because of the number of comparisons that have to be made.
Rust can do this a lot faster.

## Starting with Rust

To start with, let's imagine that I've got this rust function that I want to
call from Ruby:

```rust
pub fn return_3() -> i32 {
  return 3;
}
```

First, we'll need to prepare it to be used outside of Rust. The Rust Compiler
will rename functions, and also make them incompatible with non-rust languages
by default in order to be able to perform various kinds of optimisations. It
makes a lot sense that the default is optimised for pure rust, but that's not
what we're doing today.

So, I'll rewrite my function like this:
```rust
#[no_mangle]
pub extern fn return_3() -> i32 {
    return 3;
}
```

`#[no_mangle]` means that the name is preserved for calling in c (or really any
language that can link to a static library), `extern` means that it'll be
exported for use from whatever we compile.

Now we'll need to modify our `Cargo.toml` to allow us to build a static library,
that we can compile in to our ruby extension eventually:

```
[package]
name = "rubysoexperimenbt"
version = "0.1.0"
authors = ["Sam Phippen <samphippen@googlemail.com>"]
edition = "2018"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]
[lib]
name = "foo"
crate-type = ["staticlib"]
```

Once we do `cargo build`, we'll now see that `target/debug` contains a file
called `libfoo.a`. `.a` means that the file is a collection of native functions
that can be called by other languages, but must be compiled in with whatever
program is going to call those functions (AKA a static library).

## Making `return_3` available to Ruby

Ruby's primitive types like `Fixnum`, `String`, etc aren't C or Rust types by
default, but rather are Ruby objects. The C type for these is called `VALUE`,
which Ruby uses as a type under the hood to wrap every type of object that it
can represent. So, we need a function that can call `return_3` in a Ruby
compatible way. We'll do this in C so it can be more easily compiled in to a
Ruby extension:

```c
#include <ruby.h>
#include <stdint.h>

extern int32_t return_3();

VALUE foo_rb_return_3(VALUE klass) {
    int32_t three = return_3();
    return LONG2FIX(three);
}
```

This block of C includes `ruby.h`, a C header file that gives us various
functions to work with the ruby interpreter, and `stdint.h`, which declares
fixed width integer types (in this case we need `int32_t`, because we declared
our function to be an `i32` in rust. It then declares that `return_3` is a
function from outside of the C file (because it's declared in Rust). Then it
declares the function `foo_rb_return_3`, which calls `return_3`, and then wraps
it in the `LONG2FIX` macro. This macro comes from `ruby.h` and converts a C
`int32` (really any numeric type) in to a Ruby `Fixnum`.

## Making this file a Ruby extension.

Now that we've done that, we need to do a few more things to make this C file a
valid Ruby extension. When Ruby loads native extensions it calls
`Init_<libraryname>`, which for us is going to be `Init_foo`. So let's define
that function:


```c
#include <ruby.h>
#include <stdint.h>

extern int32_t return_3();

VALUE foo_rb_module_foo = Qnil;

VALUE foo_rb_return_3(VALUE klass) {
    int32_t three = return_3();
    return LONG2FIX(three);
}

void Init_foo(void) {
    foo_rb_module_foo = rb_define_module("Foo");
    rb_define_module_function(foo_rb_module_foo, "return_3", foo_rb_return_3, 0);
}
```

We've made a few changes here. Firstly, we've defined a new variable:
`VALUE foo_rb_module_foo = Qnil`. This is essentially declaring that we have a
new Ruby object called `foo_rb_module_foo`. When `Init_foo` is called, we call
`foo_rb_module_foo = rb_define_module("Foo");`. This will declare in Ruby a
module called `Foo` that we can hang all of our c functions off.

Then, we put our Ruby-ified `foo_rb_return_3` in our module with
`rb_define_module_function(foo_rb_module_foo, "return_3", foo_rb_return_3, 0)`

`rb_define_module_function` is the underlying C function that is equivalent to
the `module_function` keyword in Ruby. The first argument is module we want to
define that function on (in this case `Foo`, which is `foo_rb_module_foo` in C).
Then we give it a C string, which is the name of the function in Ruby
(`return_3`), then the C function to call (`foo_rb_return_3`) then the number of
positional arguments the function takes (in this case 0).Foo`, which is
`foo_rb_module_foo` in C).
Then we give it a C string, which is the name of the function in Ruby
(`return_3`), then the C function to call (`foo_rb_return_3`) then the number of
positional arguments the function takes (in this case 0).

## Building everything

Now that we've got our Rust and Ruby modules set up, we need to build
everything. Building the rust piece is easy, we can just run `cargo build`.
That'll create the `libfoo.a` we referenced earlier.

However, the Ruby-c-rust bit is a little bit more involved. Linking c code
against the Ruby interpreter isn't as easy as just calling `clang` and expecting
everything to work. But fortunately, Ruby provides a convenient tool for us,
called "mkmf" (Makemakefile for long). To use it, we write a Ruby file called
`extconf.rb` (it isn't required to be called this, but this is the conventional
name for this file).

```ruby
#!/usr/bin/env ruby
# extconf.rb
require "mkmf"

$LDFLAGS << " -Ltarget/debug -lfoo "

# preparation for compilation goes here
create_makefile("foo")
```

The only line of this file that is doing anything particularly interesting is
`$LDFLAGS << " -Ltarget/debug -lfoo "`. This line basically tells the Ruby
extension compiler where to find the Rust extension we created earlier.

`create_makefile("foo")` creates a `Makefile` that'll compile all the c files in
the current directory, expecting to find an `Init_foo` function. `Makefiles` are
somewhat complex scripts for compiling C programs that have a varied set of
dependencies.

Once that's done we can run `make`, and on my mac we'll get an output file
called `foo.bundle`.

## Running it

So! Does it work? (Yes.)

Here's how you use it:

```ruby
$: << "."
require "foo.so"

p(Foo.return_3)
```

We can require `foo.so` and it'll load the `foo.bundle` because Ruby knows how
to translate between the various operating system dynamic library names.

So, there you have it, a very simple C extension, in Ruby, without rubygems.
