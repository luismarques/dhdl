/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.arithmetic;

import std.stdio;
import dhdl;
import dhdl.testing;

class Arithmetic : Circuit
{
    @in_ UInt!8 a;
    @in_ UInt!8 b;
    @out_ UInt!8 u;
    @out_ SInt!8 s;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;
        this.instantiate!u;
        this.instantiate!s;

        this.connect(u, a - b);
        this.connect(s, a.asSInt - b.asSInt);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Arithmetic;

	c.a = 7;
	c.b = 3;
	c.eval();
	assert(c.u == 4);
	assert(c.s == 4);

	c.a = 7;
	c.b = 10;
	c.eval();
	assert(c.u == 253);
	assert(c.s == -3);
}
