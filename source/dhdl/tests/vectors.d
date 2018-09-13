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
    @in_ Vec!(Bool, 2) a;
    @out_ Vec!(Bool, 2) b;

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

        Reg reg;
        this.instantiate!reg(rom[0]);

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

class TestBundle : Bundle
{
    @in_ Bool x;
    @in_ Bool y;

    this()
    {
        this.instantiate!x;
        this.instantiate!y;
    }
}

class VectorBundlePorts : Circuit
{
    @in_ Vec!(TestBundle, 2)  a;
    @out_ Vec!(TestBundle, 2) b;

    this()
    {
        this.instantiate!a;
        this.instantiate!b;

        //this.connect((cast(TestBundle) b[1].element).x, (cast(TestBundle) a[0].element).x);
        //this.connect((cast(TestBundle) b[0].element).x, (cast(TestBundle) a[1].element).x);

        //this.connect((cast(TestBundle) b[1].element).x, (cast(TestBundle) a[0].element).x);
        auto e0 = (cast(TestBundle) b[0].element);
        e0.parent = b[0];
        auto e1 = (cast(TestBundle) a[1].element);
        e1.parent = a[1];
        this.connect(e0.x, e1.x);
    }
}

version(HWTests) unittest
{
    auto c = peekPokeTester!VectorBundlePorts;
    /+
    c.a[0].x = true;
    c.a[0].y = false;
    c.a[1].x = false;
    c.a[0].y = false;
    c.eval();
    assert(c.b[0].x == true);
    assert(c.b[1].x == false);+/
}