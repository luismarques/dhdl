module dhdl.testing;

import std.conv;
import std.format;
import std.traits;
import std.typecons;
import std.stdio;
import dhdl;
import dhdl.sim;
import dhdl.verilator;
import openmethods;

auto peekPokeTester(SomeCircuit, bool reset = true, Args...)(Args args)
{
    writeln("Testing " ~ SomeCircuit.stringof);
    static assert(is(SomeCircuit : Circuit));
    auto circuit = new SomeCircuit(args);
    writeSimulator(circuit, true);
    auto c = new PeekPokeTester!SomeCircuit(circuit);

    static if(reset)
        c.reset();

    return c;
}

interface Tester
{
    void reset(bool synchronous = true);
    void eval();
    void step(int steps = 1);
    void finish();
}

final class PeekPokeTester(SomeCircuit) : Tester
{
    this(SomeCircuit circuit)
    {
        auto vs = new VSim(circuit.prototypeName);
        pp = CompositePeekPoker!SomeCircuit(vs);
    }

    void reset(bool synchronous = true)
    {
        if(synchronous)
        {
            port!"reset" = 1;
            eval();
            clock = 1;
            eval();

            port!"reset" = 0;
            eval();
            clock = 0;
            eval();
        }
        else
        {
            port!"reset" = 1;
            eval();
            port!"reset" = 0;
            eval();
        }
    }

    void clock(bool value)
    {
        if(_defaultClock.isNull)
            port!"clock" = value;
        else
        {
            VPort!(1, false) c = _defaultClock;
            c = value;
        }
    }

    void setClock(string name)
    {
        auto p = pp.vs.getPortInfo(name);
        auto portAddr = pp.vs.getPort(p.offset);
        _defaultClock = VPort!(1, false)(portAddr);
    }

    void eval()
    {
        pp.vs.eval();
    }

    void step(int steps = 1)
    {
        eval();

        foreach(i; 0 .. steps)
        {
            clock = 1;
            pp.vs.eval();

            clock = 0;
            pp.vs.eval();
        }
    }

    void finish() {}

    auto opDispatch(string name)()
    {
        auto vp = port!name;
        return vp;
    }

    void opDispatch(string name)(ulong value)
    {
        port!name = value;
    }

private:
    auto port(string name)()
    {
        return pp.port!name;
    }

    void port(string name)(ulong value)
    {
        auto p = port!name;
        p = value;
    }

    CompositePeekPoker!SomeCircuit pp;
    Nullable!(VPort!(1, false)) _defaultClock;
}

struct CompositePeekPoker(SomeCompositePort)
{
    this(VSim vs, string path = "")
    {
        this.vs = vs;
        this.path = path;
    }

    auto opDispatch(string name)()
    {
        auto vp = port!name;
        return vp;
    }

    void opDispatch(string name)(ulong value)
    {
        port!name = value;
    }

    auto port(string name)()
    {
        static assert(hasMember!(SomeCompositePort, name),
            SomeCompositePort.stringof ~ "does not have a port named " ~ name);

        alias Port = typeof(__traits(getMember, SomeCompositePort, name));

        static if(is(Port : Composite))
        {
            return CompositePeekPoker!(Port)(vs, format("%s%s_", path, name));
        }
        else static if(is(Port == Vec!(U, n), U, int n))
        {
            return VectorPeekPoker!Port(vs, format("%s%s_", path, name));
        }

        else
        {
            auto p = vs.getPortInfo(path ~ name);
            auto portAddr = vs.getPort(p.offset);

            assert(hasMember!(Port, "staticWidth"));
            enum w = Port.staticWidth;
            enum signed = is(Port : SInt!0);

            return VPort!(w, signed)(portAddr);
        }
    }

    void port(string name)(ulong value)
    {
        auto vp = port!name;
        vp = value;
    }

    VSim vs;
    string path;
}

struct VectorPeekPoker(SomeVectorPort)
{
    this(VSim vs, string path = "")
    {
        this.vs = vs;
        this.path = path;
    }

    auto opIndex(int index)
    {
        auto p = vs.getPortInfo(path ~ index.to!string);
        auto portAddr = vs.getPort(p.offset);
        alias ElementType = SomeVectorPort.ElementType;
        enum signed = is(ElementType : SInt!0);
        return VPort!(ElementType.staticWidth, signed)(portAddr);
    }

    VSim vs;
    string path;
}
