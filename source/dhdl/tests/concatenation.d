/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.concatenation;

import std.stdio;
import dhdl;
import dhdl.testing;

class Concatenation : Circuit
{
    @in_ UInt!4 a;
    @in_ UInt!4 b;
    @in_ UInt!4 c;
    @out_ UInt!12 o;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;
        this.instantiate!c;
        this.instantiate!o;

        this.connect(o, a ~ b ~ c);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Concatenation;

	c.a = 0xA;
	c.b = 0xB;
	c.c = 0xC;
	c.eval();
	assert(c.o == 0xABC);
}
