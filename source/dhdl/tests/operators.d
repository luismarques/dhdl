/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.operators;

import std.stdio;
import dhdl;
import dhdl.testing;

class Operators : Circuit
{
    @in_ Bool a;
    @in_ Bool b;
    @in_ Bool c;
    @out_ Bool o;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;
        this.instantiate!c;
        this.instantiate!o;

        this.connect(o, (a & b) | c);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Operators;

    c.c = true;
    c.eval();
    assert(c.o == true);

    c.c = false;
    c.eval();
    assert(c.o == false);

    c.a = true;
    c.eval();
    assert(c.o == false);

    c.b = true;
    c.eval();
    assert(c.o == true);
}
