/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.wires;

import std.stdio;
import dhdl;
import dhdl.testing;

class Wires : Circuit
{
    @in_ Bool a;
    @out_ Bool b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        Wire w;
        this.instantiate!w(new Bool);

        this.connect(w, a);
        this.connect(b, w);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Wires;

	c.a = false;
	c.eval();
	assert(c.b == false);

	c.a = true;
	c.eval();
	assert(c.b == true);
}
