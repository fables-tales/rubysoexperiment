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
