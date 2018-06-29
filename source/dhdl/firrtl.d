module dhdl.firrtl;

import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.range;
import std.stdio;
import std.utf;
import std.variant;
import dhdl.dhdl;
import dhdl.util;
import openmethods;

mixin(registerMethods);

string toFIRRTL(Circuit circuit)
{
    FIRRTLWriter w = new FIRRTLWriter;
    return w.emit(circuit);
}

private:

class FIRRTLWriter
{
    string emit(Circuit circuit)
    {
        f.init();

        wfln("circuit %s :", circuit.baseName);
        enter();

        addDependency(circuit);

        bool firstDep = true;

        while(numDependencies > 0)
        {
            if(!firstDep)
                wfln();

            foreach(dep, state; dependencies)
            {
                if(state == false)
                    emitDependency(dep);
            }
            
            firstDep = false;
        }

        leave();

        return f.data;
    }

    void addDependency(Value value)
    {
        if(value !in dependencies)
        {
            dependencies[value] = false;

            ++numDependencies;
        }
    }

    void removeDependency(Value value)
    {
        dependencies[value] = true;
        --numDependencies;
    }

    void emitDependency(Value value)
    {
        if(auto c = cast(Circuit) value)
            emitDependency(c);
        else
            assert(false, "Unexpected Value type in dependency queue");
    }

    void emitDependency(Circuit circuit)
    {
        this.circuit = circuit;

        wfln("module %s :", circuit.baseName);
        enter();

        foreach(name, p; circuit.ports)
        {
            assert(p.name == name);

            if(p.direction == Direction.inout_)
                throw new Exception("inout port not supported by FIRRTL");

            wfln(p.toFIRPortDecl);
        }

        foreach(p; circuit.ports)
        {
            if(p.direction != Direction.in_ || p.isComposite)
                wfln("%s is invalid", p.name);
        }

        wfln();

        emit(circuit.bodyBlock);

        leave();

        removeDependency(circuit);
    }

    void emit(Node[] block)
    {
        foreach(s; block)
        {
            .emit(this, s);
        }
    }

    void wfln(Args...)(Args args)
    {
        f.wfln(args);
    }

    void enter()
    {
        f.enter();
    }

    void leave()
    {
        f.leave();
    }

    Formatter f;
    Circuit circuit;
    bool[Value] dependencies;
    int numDependencies;
}

void emit(FIRRTLWriter writer, virtual!Node);
void emit(FIRRTLWriter writer, virtual!Value);

@method
void _emit(FIRRTLWriter writer, Connection connection)
{
    writer.wfln("%s <= %s",
        writer.emitSymbol(connection.lhs, writer.circuit),
        writer.emitSymbol(connection.rhs, writer.circuit));
}

@method
void _emit(FIRRTLWriter writer, When when)
{
    assert(when.condition.width == 1,
        "Invalid condition width (1-bit width expected)");

    writer.wfln("when %s :", writer.emitSymbol(when.condition, writer.circuit));

    writer.enter();
    writer.emit(when.blockTrue);
    writer.leave();

    if(when.blockFalse !is null)
    {
        writer.wfln("else :");
        
        writer.enter();
        writer.emit(when.blockFalse);
        writer.leave();
    }
}

@method
void _emit(FIRRTLWriter writer, ValueDeclaration valDecl)
{
    emit(writer, valDecl.value);
}

@method
void _emit(FIRRTLWriter writer, Circuit circuit)
{
    writer.addDependency(circuit);
    writer.wfln("inst %s of %s", circuit.name, circuit.prototypeName);

    writer.wfln("%s is invalid", circuit.name);

    // TODO: allow customizing the clock and reset ports
    writer.wfln("%s.clock <= clock", circuit.name);
    writer.wfln("%s.reset <= reset", circuit.name);
}

@method
void _emit(FIRRTLWriter writer, Reg reg)
{
    assert(writer.circuit is reg.parent);

    auto regClockName = reg.clock is null ? "clock" : reg.clock.name;
    auto v = reg.value;

    if(v.isType)
    {
        writer.wfln("reg %s : %s, %s",
            reg.name,
            v.toFIRTypeName,
            regClockName);
    }
    else
    {
        writer.wfln("reg %s : %s, %s with : (reset => (reset, %s))",
            reg.name,
            v.toFIRTypeName,
            regClockName,
            writer.emitSymbol(reg.value, writer.circuit));
    }
}

@method
void _emit(FIRRTLWriter writer, Mem mem)
{
    writer.wfln("%s %s : %s[%s]",
        mem.sync ? "smem" : "cmem",
        mem.name,
        mem.value.toFIRTypeName,
        mem.depth);
}

@method
void _emit(FIRRTLWriter writer, Wire wire)
{
    writer.wfln("wire %s : %s",
        wire.name,
        wire.toFIRTypeName);
}

@method
void _emit(FIRRTLWriter writer, Vec!0 vec)
{
    writer.wfln("wire %s : %s",
        vec.name,
        vec.toFIRTypeName);

    foreach(i; 0 .. vec.depth)
    {
        auto v = vec.element(i);
        writer.wfln("%s[%s] <= %s", vec.name, i, v.toFIRSymbol(writer.circuit));
    }
}

string emitSymbol(FIRRTLWriter writer, virtual!Value, Value lastParent = null);

@method
string _emitSymbol(FIRRTLWriter writer, Value value, Value lastParent = null)
{
    return value.toFIRSymbol(lastParent);
}

@method
string _emitSymbol(FIRRTLWriter writer, Expression exp, Value lastParent = null)
{
    if(writer.dependencies.get(exp, false))
        return exp.name;

    if(exp.name is null)
        exp.name = writer.circuit.newWireName;

    if(exp.postfix)
    {
        assert(exp.args.length == 1);
        auto arg = writer.emitSymbol(exp.args[0], writer.circuit);
        writer.wfln("node %s = %s%s", exp.name, arg, exp.op);
    }
    else
    {
        auto args = exp.args.map!(a => writer.emitSymbol(a, writer.circuit)).array;
        auto params = exp.params.map!(a => a.to!string).array;
        auto r = joiner(only(args, params)).joiner(", ");
        writer.wfln("node %s = %s(%s)", exp.name, exp.op, r);
    }

    writer.dependencies[exp] = true;

    return exp.name;
}

@method
string _emitSymbol(FIRRTLWriter writer, Element e, Value lastParent = null)
{
    if(e.valueIndex !is null)
    {
        e.valueIndex.name = writer.emitSymbol(e.valueIndex, writer.circuit);
    }

    return e.toFIRSymbol;
}

@method
string _emitSymbol(FIRRTLWriter writer, MemElement e, Value lastParent = null)
{
    if(!writer.dependencies.get(e, false))
    {
        e.name = writer.circuit.newWireName;

        writer.wfln("infer mport %s = %s[%s], clock", e.name, e.parent.name,
            e.valueIndex.toFIRSymbol(lastParent));

        writer.dependencies[e.parent] = true;
    }

    return e.name;
}

string toFIRTypeName(Value value)
{
    if(value.isComposite)
    {
        auto composite = cast(Composite) value;

        auto s = composite.ports.values
            .map!(a => a.toFIRPortDecl.byCodeUnit)
            .joiner(", ".byCodeUnit);

        return format("{%s}", s);
    }

    auto type = value.type;
    string typeName;
 
    // TODO: use open methods (Element and Register must forward to their encapsulated values)
    with(ValueType) switch(type)
    {
        case clock:
            typeName = "Clock";
            break;

        case bits:
        case boolean:
        case unsignedInt:
            typeName = "UInt";
            break;

        case signedInt:
            typeName = "SInt";
            break;

        case vector:
        case memory:
            auto v = cast(Vectorial) value;
            typeName = format("%s[%s]", v.element.toFIRTypeName, v.depth);
            break;

        default:
            assert(false, "Unsupported type");
    }

    if(value.width > 0 && type != ValueType.clock && type != ValueType.vector)
        return format("%s<%s>", typeName, value.width);
    else
        return typeName;
}

unittest
{
    auto bits = new Bits!0;
    assert(bits.toFIRTypeName == "UInt");

    auto c = new Clock;
    assert(c.toFIRTypeName == "Clock");    
    c.width = 1;
    assert(c.toFIRTypeName == "Clock");

    auto b = new Bool;
    assert(b.toFIRTypeName == "UInt<1>");

    auto u = new UInt!0;
    assert(u.toFIRTypeName == "UInt");

    u.width = 8;
    assert(u.toFIRTypeName == "UInt<8>");

    auto u4 = new UInt!4;
    assert(u4.toFIRTypeName == "UInt<4>");

    auto rb = new Reg(b);
    assert(rb.toFIRTypeName == b.toFIRTypeName);

    auto ru = new Reg(u);
    assert(ru.toFIRTypeName == u.toFIRTypeName);

    auto v1 = new Vec!0(b, 2);
    assert(v1.toFIRTypeName == "UInt<1>[2]");

    auto v2 = new Vec!0(v1, 3);
    assert(v2.toFIRTypeName == "UInt<1>[2][3]");

    auto m = new Mem(new Bool, 8);
    assert(m.toFIRTypeName == "UInt<1>[8]");

    class TestBundle : Bundle
    {
        @in_ Bool b;
        @in_ UInt!32 u;

        this()
        {
            this.instantiate!b;
            this.instantiate!u;
        }
    }

    auto bundle = new TestBundle;
    assert(bundle.toFIRTypeName == "{b : UInt<1>, u : UInt<32>}");
}

/// Converts a Value into a port declaration
string toFIRPortDecl(Value value)
{
    assert(value.direction != Direction.nil, "Value must have a direction");
    assert(value.direction != Direction.inout_, "Bidirectional ports not supported");
    assert(value.name !is null);

    return format("%s%s : %s",
        (cast(Bundle) value.parent) !is null ?
            (value.direction == Direction.in_ ? "" : "flip ") :
            (value.direction == Direction.in_ ? "input " : "output "),
        value.name,
        value.toFIRTypeName);
}

unittest
{
    auto c = new Clock;
    c.direction = in_;
    c.name = "c";
    assert(toFIRPortDecl(c) == "input c : Clock");

    c.direction = Direction.out_;
    assert(toFIRPortDecl(c) == "output c : Clock");

    auto b = new Bool;
    b.direction = Direction.in_;
    b.name = "b";
    assert(toFIRPortDecl(b) == "input b : UInt<1>");

    b.direction = Direction.out_;
    assert(toFIRPortDecl(b) == "output b : UInt<1>");

    auto u = new UInt!0();
    u.direction = Direction.in_;
    u.name = "u";

    assert(toFIRPortDecl(u) == "input u : UInt");

    u.width = 8;
    assert(toFIRPortDecl(u) == "input u : UInt<8>");

    class TestBundle : Bundle
    {
        @in_ Bool b;
        @in_ UInt!8 u;

        this()
        {
            this.instantiate!b;
            this.instantiate!u;
        }
    }

    auto bundle = new TestBundle;
    bundle.direction = in_;
    bundle.name = "bundle";
    assert(toFIRPortDecl(bundle) == "input bundle : {b : UInt<1>, u : UInt<8>}");

    bundle.direction = out_;
    assert(toFIRPortDecl(bundle) == "output bundle : {b : UInt<1>, u : UInt<8>}");

    bundle.b.direction = out_;
    assert(toFIRPortDecl(bundle) == "output bundle : {flip b : UInt<1>, u : UInt<8>}");

    bundle.u.direction = out_;
    assert(toFIRPortDecl(bundle) == "output bundle : {flip b : UInt<1>, flip u : UInt<8>}");
}

string composeName(virtual!Value parent, string parentName, Value son);

@method
string _composeName(Composite parent, string parentName, Value son)
{
    if(parentName is null)
        return son.name;

    return format("%s.%s", parentName, son.name);
}

@method
string _composeName(Value parent, string parentName, Value son)
{
    if(parentName is null)
        return son.name;

    return format("%s%s", parentName, son.name);
}

string toFIRFullName(Value parent, Value son, Value lastParent)
{
    if(parent is null || parent is lastParent)
        return son.name;

    auto parentName = toFIRFullName(parent.parent, parent, lastParent);
    return composeName(parent, parentName, son);
}

string toFIRSymbol(Value value, Value lastParent = null)
{
    auto literal = value.literal;

    if(!literal.isNull)
    {
        enum fmt = "%s(%s)";
        auto typeName = value.toFIRTypeName;

        if(value.isSigned)
            return format(fmt, typeName, cast(long) literal);
        else
            return format(fmt, typeName, literal);
    }

    return toFIRFullName(value.parent, value, lastParent);
}

unittest
{
    auto bits = new Bits!0;
    bits.name = "bits";
    assert(bits.toFIRSymbol == "bits");

    auto bits42 = new Bits!0(42);
    assert(bits42.toFIRSymbol == "UInt<6>(42)");

    bits42.width = 8;
    assert(bits42.toFIRSymbol == "UInt<8>(42)");

    auto sint42 = new SInt!0(42);
    assert(sint42.toFIRSymbol == "SInt<7>(42)");

    auto sintm42 = new SInt!0(-42);
    assert(sintm42.toFIRSymbol == "SInt<7>(-42)");

    auto btrue = new Bool(true);
    assert(btrue.toFIRSymbol == "UInt<1>(1)");

    auto vec = new Vec!0(new Bool, 3);
    vec.name = "vec";
    assert(vec.toFIRSymbol == "vec");

    auto e = vec[3];
    assert(e.toFIRSymbol == "vec[3]");

    auto reg = new Reg(vec);
    reg.name = "reg";
    assert(reg.toFIRSymbol == "reg");

    auto rv = reg[2];
    assert(rv.toFIRSymbol == "reg[2]");

    class SonBundle : Bundle
    {
        @in_ Bool value;

        this()
        {
            this.instantiate!value;
        }
    }

    class ParentBundle : Bundle
    {
        @in_ SonBundle son;

        this()
        {
            this.instantiate!son;
        }
    }

    auto parent = new ParentBundle;
    parent.name = "parent";
    assert(parent.son.value.toFIRSymbol == "parent.son.value");
}
