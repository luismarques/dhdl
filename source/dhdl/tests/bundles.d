/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.bundles;

import std.stdio;
import dhdl;
import dhdl.testing;

class TestBundle : Bundle
{
    @in_ Bool x;
    @out_ UInt!32 y;

    this()
    {
        this.instantiate!x;
        this.instantiate!y;
    }
}

class Bundles1 : Circuit
{
    @in_ TestBundle a;
    @out_ TestBundle b;
    @out_ Bool x;
    @in_ UInt!32 y;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;
        this.instantiate!x;
        this.instantiate!y;

        this.connect(x, a.x);
        this.connect(a.y, y);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Bundles1;

    c.a.x = true;
    c.y = 42;
    c.eval();
	assert(c.x == true);
	assert(c.a.y == 42);
}

class Bundles2 : Circuit
{
    @in_ TestBundle a;
    @out_ TestBundle b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        version(none)
        {
            this.connect(b.x, a.x);
            this.connect(a.y, b.y);
        }
        else
            this.connect(a, b);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Bundles2;

    c.a.x = true;
    c.b.y = 42;
    c.eval();
	assert(c.b.x == true);
	assert(c.a.y == 42);
}
