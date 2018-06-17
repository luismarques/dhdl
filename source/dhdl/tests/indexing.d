/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.indexing;

import std.stdio;
import dhdl;
import dhdl.testing;

class Indexing : Circuit
{
    @in_ UInt!2 a;
    @out_ Bool b0;
    @out_ Bool b1;

    this()
    {
        this.instantiate!a;
        this.instantiate!b0;
        this.instantiate!b1;

        this.connect(b0, a[0]);
        this.connect(b1, a[1]);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Indexing;

	c.a = 0b00;
	c.eval();
	assert(c.b0 == 0);
	assert(c.b1 == 0);

	c.a = 0b01;
	c.eval();
	assert(c.b0 == 1);
	assert(c.b1 == 0);

	c.a = 0b10;
	c.eval();
	assert(c.b0 == 0);
	assert(c.b1 == 1);
}
