module dhdl.verilator;

import core.sys.posix.dlfcn;
import std.algorithm;
import std.conv;
import std.exception;
import std.format;
import std.regex;
import std.stdio;
import std.string;
import dhdl;

/// The D type used for a Verilator port of a given width
template VPortType(int width, bool signed)
{
    static assert(width > 0 && width <= 64, "Unsupported port size");

    static if(signed)
    {
        static if(width <= 8)
            alias VPortType = byte;
        else static if(width <= 16)
            alias VPortType = short;
        else static if(width <= 32)
            alias VPortType = int;
        else
            alias VPortType = long;
    }
    else
    {
        static if(width <= 8)
            alias VPortType = ubyte;
        else static if(width <= 16)
            alias VPortType = ushort;
        else static if(width <= 32)
            alias VPortType = uint;
        else
            alias VPortType = ulong;
    }
}

static assert(is(VPortType!(1, false) == ubyte));
static assert(is(VPortType!(8, false) == ubyte));
static assert(is(VPortType!(9, false) == ushort));
static assert(is(VPortType!(16, false) == ushort));
static assert(is(VPortType!(17, false) == uint));
static assert(is(VPortType!(32, false) == uint));
static assert(is(VPortType!(33, false) == ulong));

static assert(is(VPortType!(1, true) == byte));
static assert(is(VPortType!(8, true) == byte));
static assert(is(VPortType!(9, true) == short));
static assert(is(VPortType!(16, true) == short));
static assert(is(VPortType!(17, true) == int));
static assert(is(VPortType!(32, true) == int));
static assert(is(VPortType!(33, true) == long));

/// Read/write wrapper for a Verilator port
struct VPort(int width, bool signed)
{
    alias VP = VPortType!(width, signed);
    alias peek this;

    this(void* portAddr)
    {
        port = cast(VP*) portAddr;
    }

    void opAssign(ulong rhs)
    {
        debug
        {
            bool fits;

            static if(signed)
            {
                long v = rhs;
                v <<= (64 - width);
                v >>= (64 - width);
                fits = v == rhs;
            }
            else
            {
                fits = rhs.widthOf <= width;
            }

            assert(fits, "value is outside the port range");
        }

        *port = cast(VP) rhs;
    }

    auto peek()
    {
        return *port;
    }

    string toString()
    {
        return (*port).to!string;
    }

    VP* port;
}

unittest
{
    ubyte[12] _mem;
    auto mem = _mem[2 .. 10];
    auto padLeft = _mem[0 .. 2];
    auto padRight = _mem[10 .. 12];

    VPort!(1, false) port1 = mem.ptr;
    assert(mem.all!(a => a == 0));
    port1 = true;
    assert(mem == [1, 0, 0, 0, 0, 0, 0, 0]);
    port1 = false;
    assert(mem == [0, 0, 0, 0, 0, 0, 0, 0]);

    VPort!(8, false) port8 = mem.ptr;
    port8 = 254;
    assert(mem == [254, 0, 0, 0, 0, 0, 0, 0]);
    assert(port8 == 254);
    port8 = 255;
    assert(mem == [255, 0, 0, 0, 0, 0, 0, 0]);
    assert(port8 == 255);
    mem[0] = 42;
    assert(port8 == 42);

    VPort!(9, false) port9 = mem.ptr;
    port9 = 258;
    assert(mem == [2, 1, 0, 0, 0, 0, 0, 0]);

    VPort!(64, false) port64 = mem.ptr;
    port64 = 0x01_23_45_67_89_AB_CD_EF;
    assert(mem == [0xEF, 0xCD, 0xAB, 0x89, 0x67, 0x45, 0x23, 0x01]);

    assert(padLeft == [0, 0] && padRight == [0, 0]);
}

/// Does a value type have a Verilator port
/// Bundles and vectors do not; only its constituents
template hasVPort(SomeValue)
{
    static if(is(SomeValue : Bits))
        enum hasVPort = true;
    else
        enum hasVPort = false;        
}

final class VSim
{
    this(string name)
    {
        this.name = name;

        auto libName = format("rtl/%s/obj_dir/V%1$s", name);
        auto lib = dlopen(libName.toStringz, RTLD_LAZY);
        enforce(lib, "could not load circuit simulation library " ~ libName);

        New newMod = cast(New) dlsym(lib, ("new_V" ~ name).toStringz);
        enforce(newMod, "could not instantiate circuit simulation");

        top = newMod();

        string evalMangled = format("_ZN%sV%s4evalEv", name.length+1, name);
        _eval = cast(Eval) dlsym(lib, evalMangled.toStringz);
        enforce(_eval, "could not find the simulator's eval method");
    }

    PortPtr getPortInfo(string portName)
    {
        auto p = portName in portPtrs;
        if(p)
            return *p;

        auto f = File(format("rtl/%s/obj_dir/V%1$s.h", name));

        foreach(line; f.byLine)
        {
            if(line.startsWith("VL_MODULE"))
                break;
        }

        size_t offset = size_t.sizeof; // account for 'name' field (from the base class)

        auto r = ctRegex!r"\s*VL_([A-Z]+[0-9]*)\(([0-9a-zA-Z_]+),([0-9]+),";

        enum portNotFoundMsg = "port '%s' not found in header file";

        foreach(line; f.byLine)
        {
            auto m = line.matchFirst(r);

            if(!m.empty)
            {
                int size = 1;

                switch(m[1])
                {
                    case "IN16":
                    case "OUT16":
                        if(offset & 1)
                            ++offset;
                        size = 2;
                        break;

                    case "IN":
                    case "OUT":
                        while(offset & 0b11)
                            ++offset;
                        size = 4;
                        break;

                    case "SIG8":
                    case "SIG16":
                    case "UNCOPYABLE":
                        assert(false, format(portNotFoundMsg, portName));

                    default:
                }

                if(m[2] == portName)
                {
                    auto portPtr = PortPtr(offset, size);
                    portPtrs[portName] = portPtr;
                    return portPtr;
                }

                switch(m[1])
                {
                    case "IN8":
                    case "OUT8":
                        offset += 1;
                        break;

                    case "IN16":
                    case "OUT16":
                        offset += 2;
                        break;

                    case "IN":
                    case "OUT":
                        offset += (m[3].to!int+1) / 8;
                        break;
                    
                    default:
                        assert(false, "unrecognized field type in Verilator header");
                }
            }
        }

        assert(false, format(portNotFoundMsg, portName));
    }

    void* getPort(size_t offset)
    {
        return top + offset;
    }

    void eval()
    {
        _eval(top);
    }

private:
    Eval _eval;
    void* top;
    PortPtr[string] portPtrs;
    string name;
}

struct PortPtr
{
    size_t offset;
    int byteSize;
}

string vportName(Value value)
{
    return value.name;
}

unittest
{
    auto v = new Bits!0;
    v.name = "v";
    assert(v.vportName == "v");
}

private:

alias New = extern(C) void* function();
alias Eval = extern(C) void function(void*);
