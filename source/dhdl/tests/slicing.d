/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.slicing;

import std.stdio;
import dhdl;
import dhdl.testing;

class Slicing : Circuit
{
    @in_ UInt!8 a;
    @out_ UInt!4 hi;
    @out_ UInt!4 lo;

    this()
    {
        this.instantiate!a;
        this.instantiate!hi;
        this.instantiate!lo;

        this.connect(hi, a[8 .. 4]);
        this.connect(lo, a[4 .. 0]);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Slicing;

	c.a = 0xAB;
	c.eval();
	assert(c.hi == 0xA);
	assert(c.lo == 0xB);
}

// TODO: slice single bit (with indexing?)