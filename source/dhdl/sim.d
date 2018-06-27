module dhdl.sim;

import std.file : copy;
import std.format;
import std.process;
import std.stdio;
import dhdl;
import dhdl.firrtl;

// TODO: common module path formatter function

int writeSimulator(Circuit circuit, bool verbose)
{
    auto r = writeCpp(circuit, verbose);

    if(r != 0)
        return r;

    writeSimulatorMain(circuit);

    auto name = circuit.prototypeName;
    auto cmd = format("make -f V%s.mk", name);

    if(verbose)
        writeln(cmd);

    auto e = executeShell(cmd, null, Config.none, size_t.max,
        format("rtl/%s/obj_dir", name));

    if(e.status != 0)
        writeln(e.output);

    return e.status;
}

void writeSimulatorMain(Circuit circuit)
{
    static import std.file;

    auto name = circuit.prototypeName;
    auto vname = "V" ~ name;

    auto s =

`#include "%1$s.h"

extern "C" void* new_%1$s()
{
    return new %1$s;
}
`.format(vname);

    std.file.write(format("rtl/%s/obj_dir/lib.cpp", name), s);
}

int writeCpp(Circuit circuit, bool verbose)
{
    auto r = writeVerilog(circuit, verbose);
    auto name = circuit.prototypeName;

    if(r != 0)
    {
        if(verbose)
            writefln("Could not generate Verilog for %s", name);

        return r;
    }

    auto cmd = format(
        "verilator -CFLAGS -fPIC -LDFLAGS -shared --cc --exe lib.cpp %s.v",
        name);

    if(verbose)
        writeln(cmd);

    auto e = executeShell(cmd, null, Config.none, size_t.max, "rtl/" ~ name);

    if(verbose && e.status != 0)
        writeln(e.output);

    return e.status;
}

int writeVerilog(Circuit circuit, bool verbose = false)
{
    writeFIRRTL(circuit);

    auto name = circuit.prototypeName;

    auto e = executeShell(
        format("firrtl -i %1$s.fir -o %1$s.v", name),  
        null, Config.none, size_t.max, "rtl/" ~ name);

    if(verbose && e.status != 0)
        writeln(e.output);

    return e.status;
}

void writeFIRRTL(Circuit circuit)
{
    import std.file;

    auto firrtl = toFIRRTL(circuit);
    auto name = circuit.prototypeName;
    auto dir = format("rtl/%s", name);
    mkdirRecurse(dir);
    auto filename = format("%s/%s.fir", dir, name);
    std.file.write(filename, firrtl);
}
