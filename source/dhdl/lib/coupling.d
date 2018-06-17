/+
This is a DHDL test library. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.lib.coupling;

import std.stdio;
import dhdl;
import dhdl.testing;
import openmethods;

class Valid(T) : Bundle
{
    @in_ T payload;
    @in_ Bool valid;

    this(Args...)(Args args)
    {
        this.instantiate!payload(args);
        this.instantiate!valid;
    }
}

class Ready(T) : Bundle
{
    @in_ T payload;
    @out_ Bool ready;

    this(Args...)(Args args)
    {
        this.instantiate!payload(args);
        this.instantiate!ready;
    }
}

class ReadyValid(T) : Bundle
{
    @in_ T payload;
    @out_ Bool ready;
    @in_ Bool valid;

    this(Args...)(Args args)
    {
        this.instantiate!payload(args);
        this.instantiate!ready;
        this.instantiate!valid;
    }
}
