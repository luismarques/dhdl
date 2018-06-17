/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.registers;

import std.stdio;
import dhdl;
import dhdl.testing;

class Registers : Circuit
{
    @in_ Bool a;
    @out_ Bool b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        Reg reg;
        this.instantiate!reg(true.B);

        this.connect(reg, a);
        this.connect(b, reg);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Registers;

	c.a = false;
	c.step();
	assert(c.b == false);

	c.a = true;
	c.eval();
	assert(c.b == false);

	c.step();
	assert(c.b == true);

	c.a = false;
	c.step();
	assert(c.b == false);

    c.reset();
	assert(c.b == true);
}
