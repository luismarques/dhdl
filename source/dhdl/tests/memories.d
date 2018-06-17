/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.memories;

import std.stdio;
import dhdl;
import dhdl.testing;

class Memories : Circuit
{
    @out_ UInt!8 readVal;
    @in_ UInt!2 readAddr;
    @in_ UInt!8 writeVal;
    @in_ UInt!2 writeAddr;
    @in_ Bool we;

    this()
    {
        this.instantiate!readVal;
        this.instantiate!readAddr;
        this.instantiate!writeVal;
        this.instantiate!writeAddr;
        this.instantiate!we;

        Mem mem;
        this.instantiate!mem(new UInt!8, 3, false);

        when(we,
        {
            this.connect(mem[writeAddr], writeVal);
        });

        this.connect(readVal, mem[readAddr]);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!Memories;

    c.we = true;

    foreach(i; 0 .. 3)
    {
        c.writeVal = 42 + i;
        c.writeAddr = i;
        c.step();
    }

    c.we = false;

    foreach(i; 0 .. 3)
    {
        c.readAddr = i;
        c.step();
        assert(c.readVal == 42 + i);
    }
}
