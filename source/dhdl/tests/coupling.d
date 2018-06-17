/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.coupling;

import std.stdio;
import dhdl;
import dhdl.lib.coupling;
import dhdl.testing;

class Coupling : Circuit
{
    @in_ ReadyValid!(UInt!8) a;
    @out_ UInt!8 b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        Reg reg;
        this.instantiate!reg(true.B);

        this.connect(reg, reg.not);
        this.connect(a.ready, reg);

        when(reg & a.valid,
        {
            this.connect(b, a.payload);
        },
        {
            this.connect(b, 7.U);
        });
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Coupling;

    c.a.valid = true;
    c.a.payload = 42;
    c.eval();

    assert(c.b == 42);

    c.a.payload = 21;
    c.step();
    assert(c.b == 7);

    c.step();
    assert(c.b == 21);
}
