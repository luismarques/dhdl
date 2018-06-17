/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.conditionals;

import std.stdio;
import dhdl;
import dhdl.testing;

class Conditionals : Circuit
{
    @in_ Bool a;
    @in_ Bool w;
    @out_ Bool b;

    this()
    {
        this.instantiate!a;
        this.instantiate!w;
        this.instantiate!b;

        Reg reg;
        this.instantiate!reg(new Bool);

        when(w,
        {
            this.connect(reg, a);
        });

        this.connect(b, reg);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Conditionals;

	c.a = false;
    c.w = true;
	c.step();
	assert(c.b == false);

	c.a = true;
    c.w = false;
	c.eval();
	assert(c.b == false);

    c.w = true;
	c.step();
	assert(c.b == true);
}
