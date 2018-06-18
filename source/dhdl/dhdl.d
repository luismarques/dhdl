module dhdl.dhdl;

import std.algorithm;
import std.conv;
import std.format;
import std.range;
import std.stdio;
import std.traits;
import std.typecons;
import std.variant;
import dhdl.util;
import openmethods;

/// The direction in which values flow
enum Direction
{
    nil = -1, // uninitialized
    in_,
    out_,
    inout_,
    clocked, // reg-like values
}

// Convenience aliases for common port directions
enum in_ = Direction.in_;
enum out_ = Direction.out_;
enum inout_ = Direction.inout_;

/// Is the Direction some kind of input
bool isInput(Direction dir)
{
    return
        dir == in_ ||
        dir == inout_ ||
        dir == Direction.clocked;
}

/// Is the Direction some kind of output
bool isOutput(Direction dir)
{
    return
        dir == out_ ||
        dir == inout_ ||
        dir == Direction.clocked;
}

/// Value width, in bits
struct Width
{
    int width;
    alias width this;
}

alias W = Width;

enum unknownWidth = -1;

enum ValueType
{
    bits,
    clock,
    boolean,
    unsignedInt,
    signedInt,
    memory,
    vector,
    composite, // bundles, circuits
}

interface Value
{
    string name();
    void name(string);
    Value parent();
    void parent(Value);
    int width();
    Direction direction();
    void direction(Direction);
    ValueType type();
    Nullable!ulong literal();
    Value slice(int, int);
    Value index(int);
    Value index(Value);
    Value element(int = 0);
    bool isType();

    Value opBinary(string op)(Value rhs)
    {
        static if(op == "&")
            return and(this, rhs);
        else static if(op == "|")
            return or(this, rhs);
        else static if(op == "^")
            return xor(this, rhs);
        else static if(op == "+")
            return add(this, rhs);
        else static if(op == "-")
            return sub(this, rhs);
        else static if(op == "~")
            return cat(this, rhs);
        else
            static assert(false, "Unknown binary operation");
    }

    Value opIndex()(int i)
    {
        return index(i);
    }

    Value opIndex()(Value i)
    {
        return index(i);
    }
    
    Value opSlice()(int a, int b)
    {
        return slice(a, b);
    }
}

/// Convenience function to create a Bits
auto Bt(int n = 0)(ulong literal)
{
    return new Bits!n(literal);
}

/// Convenience function to create a Bool
auto B(bool literal)
{
    return new Bool(literal);
}

/// Convenience function to create an UInt
auto U(int n = 0)(ulong literal)
{
    return new UInt!n(literal);
}

/// Convenience function to create an SInt
auto S(int n = 0)(long literal)
{
    return new SInt!n(literal);
}

Direction flippedDirection(Direction dir)
{
    if(dir == in_)
        return out_;
    else if(dir == out_)
        return in_;
    else
        assert(false, "attempting to flip invalid port direction");
}

bool isPortOf(Value value, Composite composite)
{
    foreach(name, port; composite.ports)
    {
        if(value is port)
            return true;
    }

    auto parent = value.parent;

    if(parent !is null)
    {
        return parent.isPortOf(composite);
    }
    
    return false;
}

Direction flowDirection(Value value, Composite pointOfView)
{
    auto dir = value.direction;

    while(value.parent !is null)
    {
        auto parent = value.parent;

        if(parent.direction == out_)
            dir = dir.flippedDirection;

        if(parent is pointOfView)
            break;

        value = value.parent;
    }

    if(value.isPortOf(pointOfView))
        return dir;
    else
        return dir.flippedDirection;
}

interface Vectorial : Value
{
    int depth();
    void depth(int);
}

bool isComposite(Value value)
{
    return value.type == ValueType.composite;
}

interface Composite : Value
{
    Value[string] ports();
    void declare(Value);
}

template Bits(int n)
{
    static if(n == 0)
    {
        class Bits : Value
        {
            this() {}

            this(ulong _literal)
            {
                this._literal = _literal;
            }

            string name()
            {
                return _name;
            }

            void name(string _name)
            {
                this._name = _name;
            }

            Value parent()
            {
                return _parent;
            }

            void parent(Value _parent)
            {
                this._parent = _parent;
            }

            int width()
            {
                return _width;
            }

            void width(int _width)
            {
                this._width = _width;
            }

            Direction direction()
            {
                return dir;
            }

            void direction(Direction dir)
            {
                this.dir = dir;
            }

            ValueType type()
            {
                return ValueType.bits;
            }

            Nullable!ulong literal()
            {
                return _literal;
            }

            Value slice(int high, int low)
            {
                return .slice(this, high, low);
            }

            Value index(int i)
            {
                return idx(this, i);
            }

            Value index(Value i)
            {
                assert(false, "Unsupported");
            }

            Value element(int i = 0)
            {
                assert(false);
            }

            bool isType()
            {
                return literal.isNull;
            }

            enum staticWidth = 0;

        private:
            string _name;
            int _width;
            Direction dir;
            Value _parent;
            Nullable!ulong _literal;
        }
    }
    else
    {
        class Bits : Bits!0
        {
            this() {}

            this(ulong _literal)
            {
                super(_literal);
            }

            override int width()
            {
                return n;
            }
        
            override void width(int _width)
            {
                assert(_width == n);
            }

            enum staticWidth = n;
        }
    }

    mixin registerClasses!(Bits);
}

class Clock : Bits!1
{
    override ValueType type()
    {
        return ValueType.clock;
    }
}

class Bool : Bits!1
{
    this()
    {
        _width = 1;
    }

    this(bool _literal)
    {
        _width = 1;
        this._literal = _literal;
    }

    override ValueType type()
    {
        return ValueType.boolean;
    }
}

template UInt(int n)
{
    static if(n == 0)
    {
        class UInt : Bits!0
        {
            this() {}

            this(ulong _literal)
            {
                this._literal = _literal;
            }

            this(Width width)
            {
                this.width = width;
            }

            this(ulong literal, Width width)
            {
                this._literal = literal;
                this.width = width;
            }

            override ValueType type()
            {
                return ValueType.unsignedInt;
            }
        }
    }
    else
    {
        class UInt : UInt!0
        {
            this()
            {
                this._width = n;
            }

            this(ulong literal)
            {
                this._literal = literal;
                this._width = n;
            }

            this(Width _width)
            {
                assert(_width == n);
                this.width = n;
            }

            this(ulong literal, Width _width)
            {
                assert(_width == n);
                this._literal = literal;
                this._width = n;
            }

            override void width(int _width)
            {
                assert(_width == n);
                this._width = n;
            }

            enum staticWidth = n;
        }
    }

    mixin registerClasses!(UInt);
}

template SInt(int n)
{
    static if(n == 0)
    {
        class SInt : Bits!0
        {
            this() {}

            this(ulong _literal)
            {
                this._literal = _literal;
            }

            this(Width width)
            {
                this.width = width;
            }

            this(ulong literal, Width width)
            {
                this._literal = literal;
                this.width = width;
            }

            override ValueType type()
            {
                return ValueType.signedInt;
            }
        }
    }
    else
    {
        class SInt : SInt!0
        {
            this()
            {
                this._width = n;
            }

            this(ulong literal)
            {
                this._literal = literal;
                this._width = n;
            }

            this(Width _width)
            {
                assert(_width == n);
                this.width = n;
            }

            this(ulong literal, Width _width)
            {
                assert(_width == n);
                this._literal = literal;
                this._width = n;
            }

            override void width(int _width)
            {
                assert(_width == n);
                this._width = n;
            }

            enum staticWidth = n;
        }
    }

    mixin registerClasses!(SInt);
}

class Wire : Value
{
    this(Value value)
    {
        this.value = value;
    }

    string name()
    {
        return _name;
    }

    void name(string _name)
    {
        this._name = _name;
    }

    Value parent()
    {
        return _parent;
    }

    void parent(Value _parent)
    {
        this._parent = _parent;
    }

    int width()
    {
        return value.width;
    }

    Direction direction()
    {
        return Direction.nil; //value.direction;
    }

    void direction(Direction dir)
    {
        assert(false, "Can't set wire direction");
    }

    ValueType type()
    {
        return value.type;
    }

    Nullable!ulong literal()
    {
        return Nullable!ulong.init;
    }

    Value index(int i)
    {
        return value.index(i);
    }

    Value index(Value i)
    {
        return value.index(i);
    }

    Value slice(int a, int b)
    {
        return value.slice(a, b);
    }

    Value element(int i = 0)
    {
        return value.element(i);
    }

    bool isType()
    {
        return value.isType;
    }

private:
    string _name;
    Value _parent;
    Value value;
}

class Bundle : Composite
{
    this()
    {
        // Templated subclasses are not automatically registered
        // with the openmethods library. This solves the problem.
        if(this.classinfo.deallocator is null)
            this.classinfo.deallocator = Bundle.classinfo.deallocator;
    }

    string name()
    {
        return _name;
    }

    void name(string _name)
    {
        this._name = _name;
    }

    Value parent()
    {
        return _parent;
    }

    void parent(Value _parent)
    {
        this._parent = _parent;
    }

    int width()
    {
        return unknownWidth;
    }
    
    Direction direction()
    {
        return dir;
    }

    void direction(Direction dir)
    {
        this.dir = dir;
    }

    ValueType type()
    {
        return ValueType.composite;
    }

    Nullable!ulong literal()
    {
        return Nullable!ulong.init;
    }

    void declare(Value value)
    {
        if(value.direction != Direction.nil)
            _ports[value.name] = value;
    }

    Value[string] ports()
    {
        return _ports;
    }

    Value index(int i)
    {
        assert(false);
    }

    Value index(Value i)
    {
        assert(false);
    }

    Value slice(int a, int b)
    {
        assert(false);
    }

    Value element(int i = 0)
    {
        assert(false);
    }

    bool isType()
    {
        return true;
    }

private:
    string _name;
    Value _parent;
    Value[string] _ports;
    Direction dir;
}

unittest
{
    class SonBundle : Bundle
    {
        @in_ Bool vin;
        @out_ Bool vout;

        this()
        {
            this.instantiate!vin;
            this.instantiate!vout;
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

    auto p = new ParentBundle;

    assert(p.son.vin.direction == in_);
    assert(p.son.vout.direction == out_);

    assert(p.son.vin.isPortOf(p.son));
    assert(p.son.vout.isPortOf(p.son));
    assert(p.son.vin.isPortOf(p));
    assert(p.son.vout.isPortOf(p));

    assert(flowDirection(p.son.vin, p.son) == in_);
    assert(flowDirection(p.son.vout, p.son) == out_);
    assert(flowDirection(p.son.vin, p) == in_);
    assert(flowDirection(p.son.vout, p) == out_);

    p.direction = out_;
    assert(flowDirection(p.son.vin, p) == out_);
}

template Vec(Args...)
{
    static assert(Args.length > 0 && Args.length <= 2);

    static if(Args.length == 2)
    {
        alias T = Args[0];
        enum n = Args[1];
    }
    else
    {
        static assert(Args[0] == 0);
        alias T = void;
        enum n = 0;
    }

    static if(n == 0)
    {
        class Vec : Vectorial
        {
            this(Value value)
            {
                value.parent = this;
                values = [value];
            }

            this(Value[] values)
            {
                foreach(value; values)
                    value.parent = this;

                this.values = values;
                _depth = values.length.to!int;
            }

            this(Value value, int depth)
            {
                value.parent = this;
                this.depth = depth;
                values = [value];
            }

            string name()
            {
                return _name;
            }

            Value parent()
            {
                return _parent;
            }

            void parent(Value _parent)
            {
                this._parent = _parent;
            }

            void name(string _name)
            {
                this._name = _name;
            }

            int width()
            {
                return unknownWidth;
            }

            void width(int _width)
            {
                assert(false, "Cannot set width of a Vec");
            }

            int depth()
            {
                return _depth;
            }
    
            void depth(int _depth)
            {
                this._depth = _depth;
            }

            Direction direction()
            {
                return dir;
            }

            void direction(Direction dir)
            {
                this.dir = dir;
            }

            ValueType type()
            {
                return ValueType.vector;
            }

            Nullable!ulong literal()
            {
                return Nullable!ulong.init;
            }

            Element index(int i)
            {
                auto e = new Element(i);
                e.parent = this;
                return e;
            }

            Element index(Value i)
            {
                auto e = new Element(i);
                e.parent = this;
                return e;
            }

            Value slice(int a, int b)
            {
                assert(false, "Slicing vectors not yet supported"); // TODO
            }

            Value element(int i = 0)
            {
                return values[i];
            }

            bool isType()
            {
                return values[0].isType;
            }

        private:
            string _name;
            Value _parent;
            Value[] values;
            Direction dir;
            int _depth;
        }
    }
    else
    {
        class Vec : Vec!0
        {
            this()
            {
                super(new T, n);
            }

            this(Value value)
            {
                super(value, n);
            }

            this(Value[] values)
            {
                assert(values.length == n);
                super(values);
            }

            this(Value value, int depth)
            {
                assert(depth == n);
                super(value, depth);
            }

            override int depth()
            {
                return n;
            }
        
            override void depth(int _depth)
            {
                assert(_depth == n);
            }

            alias ElementType = T;
            enum staticDepth = n;
        }
    }

    mixin registerClasses!(Vec);
}

/// Vector element
class Element : Value
{
    this(int index)
    {
        constIndex = index;
    }

    this(Value index)
    {
        valueIndex = index;
    }

    string name()
    {
        if(valueIndex !is null)
            return format("[%s]", valueIndex.name);
        else
            return format("[%s]", constIndex.to!string);
    }

    void name(string _name)
    {
        this._name = _name;
    }

    Value parent()
    {
        return _parent;
    }

    void parent(Value _parent)
    {
        this._parent = _parent;
    }

    int width()
    {
        return parent.width;
    }

    Direction direction()
    {
        return Direction.nil;
    }

    void direction(Direction dir)
    {
        assert(false, "Can't set direction of vector element");
    }

    ValueType type()
    {
        return parent.element.type;
    }

    Nullable!ulong literal()
    {
        return Nullable!ulong.init;
    }

    Value index(int i)
    {
        return parent.index(i);
    }

    Value index(Value i)
    {
        return parent.index(i);
    }

    Value slice(int a, int b)
    {
        return parent.element.slice(a, b);
    }

    Value element(int i = 0)
    {
        return parent.element(i);
    }

    bool isType()
    {
        return parent.element.isType;
    }

private:
    string _name;
    Value _parent;
    public Value valueIndex; // TODO: visibility
    int constIndex;
}

class Mem : Vectorial
{
    this(Value value, int depth, bool sync = true)
    {
        value.parent = this;
        this.value = value;
        this.depth = depth;
        this._sync = sync;
    }

    string name()
    {
        return _name;
    }

    Value parent()
    {
        return _parent;
    }

    void parent(Value _parent)
    {
        this._parent = _parent;
    }

    void name(string _name)
    {
        this._name = _name;
    }

    int width()
    {
        return unknownWidth;
    }

    void width(int _width)
    {
        assert(false, "Can't set width of a Mem");
    }

    int depth()
    {
        return _depth;
    }
    
    void depth(int _depth)
    {
        this._depth = _depth;
    }

    Direction direction()
    {
        return dir;
    }

    void direction(Direction dir)
    {
        this.dir = dir;
    }

    ValueType type()
    {
        return ValueType.memory;
    }

    Nullable!ulong literal()
    {
        return Nullable!ulong.init;
    }

    Element index(int i)
    {
        auto e = new MemElement(i);
        e.parent = this;
        return e;
    }

    Element index(Value i)
    {
        auto e = new MemElement(i);
        e.parent = this;
        return e;
    }

    Value slice(int a, int b)
    {
        assert(false);
    }

    Value element(int i = 0)
    {
        assert(i == 0); // TODO
        return value;
    }

    bool isType()
    {
        return true; // TODO
    }

    bool sync()
    {
        return _sync;
    }

private:
    string _name;
    Value _parent;
    public Value value; // TODO: visibility
    Direction dir;
    int _depth;
    bool _sync;
}

class MemElement : Element
{
    this(int index)
    {
        super(index);
    }

    this(Value index)
    {
        super(index);
    }

    override string name()
    {
        return _name;
    }

    override void name(string _name)
    {
        this._name = _name;
    }
}

class Reg : Value
{
    this(Value value, Clock clock = null)
    {
        this.value = value;
        this.clock = clock;
        //value.parent = this;
    }

    string name()
    {
        return _name;
    }

    void name(string _name)
    {
        this._name = _name;
    }

    Value parent()
    {
        return _parent;
    }

    void parent(Value _parent)
    {
        this._parent = _parent;
    }

    int width()
    {
        return value.width;
    }

    Direction direction()
    {
        return value.direction;
    }

    void direction(Direction dir)
    {
        assert(false, "Can't set register direction");
    }

    ValueType type()
    {
        return value.type;
    }

    Nullable!ulong literal()
    {
        return Nullable!ulong.init;
    }

    Value index(int i)
    {
        auto e = new Element(i);
        e.parent = this;
        return e;
    }

    Value index(Value i)
    {
        auto e = new Element(i);
        e.parent = this;
        return e;
    }

    Value slice(int a, int b)
    {
        return .slice(this, a, b);
    }

    Value element(int i = 0)
    {
        return value.element(i);
    }

    bool isType()
    {
        return value.isType;
    }

private:
    string _name;
    Value _parent;
    public Value value; // TODO: visibility

public: // TODO: visibility
    Clock clock;
}

class Circuit : Composite
{
    @in_ Clock clock;
    @in_ Bool reset;

    this(bool clocked = true)
    {
        // Templated subclasses are not automatically registered
        // with the openmethods library. This solves the problem.
        if(this.classinfo.deallocator is null)
            this.classinfo.deallocator = Circuit.classinfo.deallocator;

        if(clocked)
        {
            this.instantiate!clock;
            this.instantiate!reset;
        }

        blockStack = [&bodyBlock];
    }

    Value parent()
    {
        return _parent;
    }

    void parent(Value _parent)
    {
        this._parent = _parent;
    }

    string prototypeName()
    {
        return this.baseName;
    }

    string name()
    {
        return _name;
    }

    void name(string _name)
    {
        this._name = _name;
    }

    int width()
    {
        return unknownWidth;
    }

    Direction direction()
    {
        return dir;
    }

    void direction(Direction dir)
    {
        this.dir = dir;
    }

    ValueType type()
    {
        return ValueType.composite;
    }

    Nullable!ulong literal()
    {
        return Nullable!ulong.init;
    }

    Value[string] ports()
    {
        return _ports;
    }

    void declare(Value value)
    {
        if(value.direction != Direction.nil)
            _ports[value.name] = value;
        else
            currentBlock ~= new ValueDeclaration(value);
    }

    void when(Value condition, void delegate() blockTrue,
        void delegate() blockFalse = null)
    {
        auto when = new When(this, condition);

        blockStack ~= &when.blockTrue;
        blockTrue();
        blockStack.popBack();

        if(blockFalse !is null)
        {
            blockStack ~= &when.blockFalse;
            blockFalse();
            blockStack.popBack();
        }

        currentBlock ~= when;
    }

    void match(Args...)(Value value, Args args)
    {
        static assert(args.length % 2 == 0);
        
        auto when = new When(this, value.eq(args[0]));

        blockStack ~= &when.blockTrue;
        args[1]();
        blockStack.popBack();
        currentBlock ~= when;

        static if(args.length > 2)
            match(value, args[2 .. $]);
    }

    auto ref currentBlock()
    {
        return *blockStack[$-1];
    }

    string newWireName()
    {
        return format("_T_%s", wireCounter++);
    }

    Value index(int i)
    {
        assert(false);
    }

    Value index(Value i)
    {
        assert(false);
    }

    Value slice(int a, int b)
    {
        assert(false);
    }

    Value element(int i = 0)
    {
        assert(false);
    }

    bool isType()
    {
        return true;
    }

private:
    Value _parent;
    Value[string] _ports;

    // instance properties
    string _name;
    Direction dir;

public: // TODO: visibility
    Node[] bodyBlock;
    Node[]*[] blockStack;
    Node[] statements;
    int wireCounter;
    bool hasClock;
}

void instantiate(alias value, Parent, Args...)(Parent parent, Args args)
{
    alias T = typeof(value);
    auto name = value.stringof.baseName;
    value = new T(args);
    value.parent = parent;
    value.name = name;

    static if(hasUDA!(value, in_))
        value.direction = in_;
    else static if(hasUDA!(value, out_))
        value.direction = out_;
    else static if(hasUDA!(value, inout_))
        value.direction = inout_;

    parent.declare(value);
}

void connect(DstPort, SrcPort)(Circuit circuit, DstPort dst, SrcPort src)
    if(is(DstPort : Value) && !is(DstPort : Composite) &&
        is(SrcPort : Value) && !is(SrcPort : Composite))
{
    static if(hasMember!(DstPort, "staticWidth") && hasMember!(SrcPort, "staticWidth"))
        static assert(src.staticWidth <= dst.staticWidth, "mismatched port widths");

    assert(dst !is null);
    assert(src !is null);

    if(src.direction != Direction.nil)
    {
        auto srcDir = flowDirection(src, circuit);
        assert(srcDir.isInput, "Connecting from invalid source");
    }

    if(dst.direction != Direction.nil)
    {
        auto dstDir = flowDirection(dst, circuit);
        assert(dstDir.isOutput, "Connecting to invalid destination");
    }

    circuit.currentBlock ~= new Connection(dst, src);
}

void connect(DstPort, SrcPort)(Circuit circuit, DstPort dst, SrcPort src)
    if(is(DstPort : Composite) && is(SrcPort : Composite))
{
    assert(dst !is null);
    assert(src !is null);

    static foreach(mstr; __traits(allMembers, DstPort))
    {{
        static if(mstr != "Monitor" && mstr != "_parent")
        {
            alias m = typeof(__traits(getMember, DstPort, mstr));
            
            static if(is(m : Value))
            {
                auto a = __traits(getMember, src, mstr);
                auto b = __traits(getMember, dst, mstr);

                auto aDir = flowDirection(a, circuit);
                auto bDir = flowDirection(b, circuit);

                if(aDir.isOutput)
                {
                    assert(bDir.isInput);
                    circuit.connect(a, b);
                }
                else
                {
                    assert(bDir.isOutput);
                    circuit.connect(b, a);
                }
            }
        }
    }}
}

class Expression : Value
{
    this(string op, Value[] args, int[] params = null)
    {
        this.op = op;
        this.args = args;
        this.params = params;

        auto result = new Bits!0;
        result.direction = out_;
        this.result = result;
    }

    string name()
    {
        return _name;
    }

    void name(string _name)
    {
        this._name = _name;
    }

    Value parent()
    {
        return null;
    }

    void parent(Value)
    {
        assert(false, "Can't set parent of expression");
    }

    int width()
    {
        return result.width;
    }

    void width(int _width)
    {
        result.width = _width;
    }

    Direction direction()
    {
        assert(result.direction == out_);
        return out_;
    }

    void direction(Direction dir)
    {
        assert(false, "Can't set expression direction");
    }

    ValueType type()
    {
        return result.type;
    }

    Nullable!ulong literal()
    {
        return Nullable!ulong.init;
    }

    Value index(int i)
    {
        return result.index(i);
    }

    Value index(Value i)
    {
        return result.index(i);
    }

    Value slice(int a, int b)
    {
        return result.slice(a, b);
    }

    Value element(int i = 0)
    {
        return result.element(i);
    }

    bool isType()
    {
        return true; // TODO: not true of asSInt / asUInt
    }

    // TODO: visibility
    string _name;
    string op;
    Value[] args;
    int[] params;
    Bits!0 result;
    bool postfix;
    //bool emitted; // TODO: remove
}

/// Interprets the bits as an unsigned integer
auto asUInt(Value a)
{
    auto exp = new Expression("asUInt", [a]);
    exp.width = a.width;
    return exp;
}

/// Interprets the bits as a signed integer
auto asSInt(Value a)
{
    auto exp = new Expression("asSInt", [a]);
    exp.width = a.width;
    return exp;
}

/// a ~ b
auto cat(Value a, Value b)
{
    auto exp = new Expression("cat", [a, b]);
    exp.width = a.width + b.width;
    return exp;
}

/// a[i]
auto idx(Value a, int i)
{
    return new Expression("bits", [a], [i, i]);
}

/// ~a
auto not(Value a)
{
    auto exp = new Expression("not", [a]);
    exp.width = a.width;
    return exp;
}

/// a & b
auto and(Value a, Value b)
{
    auto exp = new Expression("and", [a, b]);
    exp.width = max(a.width, b.width);
    return exp;
}

/// a | b
auto or(Value a, Value b)
{
    auto exp = new Expression("or", [a, b]);
    exp.width = max(a.width, b.width);
    return exp;
}

/// a ^ b
auto xor(Value a, Value b)
{
    auto exp = new Expression("xor", [a, b]);
    exp.width = max(a.width, b.width);
    return exp;
}

/// a + b
auto add(Value a, Value b)
{
    auto exp = new Expression("add", [a, b]);
    exp.width = max(a.width, b.width);
    return exp;
}

/// a - b
auto sub(Value a, Value b)
{
    auto exp = new Expression("sub", [a, b]);
    exp.width = max(a.width, b.width);
    return exp;
}

/// a == b
auto eq(Value a, Value b)
{
    auto exp = new Expression("eq", [a, b]);
    exp.width = 1;
    return exp;
}

/// a != b
auto neq(Value a, Value b)
{
    auto exp = new Expression("neq", [a, b]);
    exp.width = 1;
    return exp;
}

/// a > b
auto gt(Value a, Value b)
{
    auto exp = new Expression("gt", [a, b]);
    exp.width = 1;
    return exp;
}

/// a >= b
auto geq(Value a, Value b)
{
    auto exp = new Expression("geq", [a, b]);
    exp.width = 1;
    return exp;
}

/// a < b
auto lt(Value a, Value b)
{
    auto exp = new Expression("lt", [a, b]);
    exp.width = 1;
    return exp;
}

/// a <= b
auto leq(Value a, Value b)
{
    auto exp = new Expression("leq", [a, b]);
    exp.width = 1;
    return exp;
}

/// node[high .. low] (high limit is open interval)
auto slice(Value a, int high, int low)
{
    assert(low >= 0);
    assert(high > low); // open interval
    return new Expression("bits", [a], [high-1, low]);
}

/// Number of bits necessary to hold `x`.
/// A zero value is assumed to be 1-bit wide.
int widthOf(ulong x)
{
    import core.bitop : bsr;
    return x == 0 ? 1 : bsr(x)+1;
}

unittest
{
    assert(widthOf(0b0000_0000) == 1);
    assert(widthOf(0b0000_0001) == 1);
    assert(widthOf(0b0000_0010) == 2);
    assert(widthOf(0b0000_0011) == 2);
    assert(widthOf(0b0000_0100) == 3);
    assert(widthOf(0b0000_0101) == 3);
    assert(widthOf(0b0000_0110) == 3);
    assert(widthOf(0b0000_0111) == 3);
    assert(widthOf(0b0000_1000) == 4);
    assert(widthOf(0b0000_1001) == 4);
    assert(widthOf(0b0000_1001) == 4);
    assert(widthOf(0b0000_1111) == 4);
    assert(widthOf(0b0001_0000) == 5);
    assert(widthOf(0b0010_0000) == 6);
    assert(widthOf(0b0100_0000) == 7);
    assert(widthOf(0b0111_1111) == 7);
    assert(widthOf(0b1000_0000) == 8);
    assert(widthOf(0b1111_1111) == 8);

    assert(widthOf(0xFFFF) == 16);
    assert(widthOf(0xFFFF_FFFF) == 32);

    assert(widthOf(0x7FFF_FFFF_FFFF_FFFF) == 63);
    assert(widthOf(0x8000_0000_0000_0000) == 64);
    assert(widthOf(0xFFFF_FFFF_FFFF_FFFF) == 64);
}

class Node {}

class ValueDeclaration : Node
{
    this(Value value)
    {
        this.value = value;
    }

    Value value;
}

class Connection : Node
{
    this(Value lhs, Value rhs)
    {
        this.lhs = lhs;
        this.rhs = rhs;
    }

    Value lhs;
    Value rhs;
}

class When : Node
{
    this(Circuit circuit)
    {
        this.circuit = circuit;
    }

    this(Circuit circuit, Value condition)
    {
        this.circuit = circuit;
        this.condition = condition;
    }

    Value condition;
    Node[] blockTrue;
    Node[] blockFalse;
    Circuit circuit;
}
