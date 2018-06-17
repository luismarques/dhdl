/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.clocking;

import std.stdio;
import dhdl;
import dhdl.testing;

class Clocked : Circuit
{
    @in_ Clock clk;
    @in_ Bool a;
    @out_ Bool b;

    this()
    {
        this.instantiate!clk;
        this.instantiate!a;
        this.instantiate!b;

        Reg r;
        this.instantiate!r(new Bool, clk);

        this.connect(r, a);
        this.connect(b, r);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Clocked;
    c.setClock("clk");

    c.a = true;
    c.b = false;
    c.eval();
    assert(c.b == false);

    // automatic clock advancing
    c.step();
    assert(c.b == true);

    // manual clock advancing
    c.a = false;
    c.clk = true;
    c.eval();
    assert(c.b == false);
    c.clk = false; // set it back to 0 before calling `step` again
}
