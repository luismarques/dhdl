/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.composition;

import std.stdio;
import dhdl;
import dhdl.testing;

class Outer : Circuit
{
    @in_ Bool a;
    @out_ Bool b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        Inner inner;
        this.instantiate!inner;

        this.connect(inner.x, a);
        this.connect(b, inner.y);
    }
}

class Inner : Circuit
{
    @in_ Bool x;
    @out_ Bool y;

    this()
    {
        this.instantiate!x;
        this.instantiate!y;

        this.connect(y, x.not);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Outer;

    c.a = false;
    c.eval();
    assert(c.b == true);

    c.a = true;
    c.eval();
    assert(c.b == false);
}
