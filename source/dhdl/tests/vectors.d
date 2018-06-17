/+
This is a DHDL test circuit. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.tests.vectors;

import std.stdio;
import dhdl;
import dhdl.testing;

class VectorPorts : Circuit
{
    @in_ Vec!(Bool, 3) a;
    @out_ Vec!(Bool, 3) b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        this.connect(b[1], a[0]);
        this.connect(b[0], a[1]);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!VectorPorts;

    c.a[0] = true;
    c.a[1] = false;
    c.eval();
    assert(c.b[0] == false);
    assert(c.b[1] == true);

    c.a[0] = false;
    c.a[1] = true;
    c.eval();
    assert(c.b[0] == true);
    assert(c.b[1] == false);
}

class VectorReg : Circuit
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

        auto vec = new Vec!(UInt!8, 3);

        Reg reg;
        this.instantiate!reg(vec);

        when(we,
        {
            this.connect(reg[writeAddr], writeVal);
        });

        this.connect(readVal, reg[readAddr]);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!VectorReg;

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
        c.eval();
        assert(c.readVal == 42 + i);
    }    
}

class VectorROM : Circuit
{
    @out_ UInt!8 readVal;
    @in_ UInt!2 readAddr;

    this()
    {
        this.instantiate!readVal;
        this.instantiate!readAddr;

        Vec!(UInt!8, 4) rom;
        this.instantiate!rom(cast(Value[])
        [
            42.U,
            43.U,
            44.U,
            45.U,
        ]);

        this.connect(readVal, rom[readAddr]);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!VectorROM;

    foreach(i; 0 .. 3)
    {
        c.readAddr = i;
        c.eval();
        assert(c.readVal == 42 + i);
    }    
}
