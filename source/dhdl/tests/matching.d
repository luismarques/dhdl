/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.matching;

import std.stdio;
import dhdl;
import dhdl.testing;

class Matching : Circuit
{
    @in_ UInt!2 a;
    @out_ SInt!21 b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        match(a,
            0.U, {
                this.connect(b, 42.S);
            },
            1.U, {
                this.connect(b, 7.S);
            },
            2.U, {
                this.connect(b, 1_000_000.S);
            },
            3.U, {
                this.connect(b, (-3).S);
            },
        );
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Matching;

	c.a = 0;
    c.eval();
	assert(c.b == 42);

	c.a = 1;
    c.eval();
	assert(c.b == 7);

	c.a = 2;
    c.eval();
	assert(c.b == 1_000_000);

	c.a = 3;
    c.eval();
	assert(c.b == -3);
}
