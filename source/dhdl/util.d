module dhdl.util;

import std.algorithm;
import std.format;
import std.range;

/// Given an object, returns its class name without the package
/// Example: foo.bar.Bar -> Bar
string baseName(Object object)
{
    return object.classinfo.name.baseName;
}

/// Given an identifier, returns its unqualified name
/// Example: foo.bar.Bar -> Bar
/// Example: this.foo -> foo
string baseName(string name)
{
    auto dotIndex = name.retro.countUntil('.');

    if(dotIndex >= 0)
        name = name[$ - dotIndex .. $];

    return name;
}

unittest
{
    class X {}
    assert(baseName(new X) == "X");

    assert(baseName("") == "");
    assert(baseName(".") == "");
    assert(baseName("a.") == "");
    assert(baseName("A") == "A");
    assert(baseName(".A") == "A");
    assert(baseName("a.A") == "A");
    assert(baseName("a.b.B") == "B");
}

struct Formatter
{
    void init()
    {
        writer = appender!string();
    }

    void wfln(Args...)(Args args)
    {
        static if(Args.length > 0)
        {
            alias fmt = args[0];

            if(fmt != "")
            {
                foreach(s; ' '.repeat(4).repeat(indentLevel))
                    writer.put(s);

                writer.formattedWrite(fmt, args[1..$]);
            }
        }

        writer.formattedWrite("\n");
    }

    void enter()
    {
        ++indentLevel;
    }

    void leave()
    {
        --indentLevel;
    }

    string data()
    {
        return writer.data;
    }

private:
    Appender!string writer;
    int indentLevel;
}

unittest
{
    Formatter f;
    f.init();

    f.wfln();
    assert(f.data == "\n");

    f.enter();
    f.wfln();
    assert(f.data == "\n\n");

    f.wfln("");
    assert(f.data == "\n\n\n");

    f.wfln("X = (%s, %s)", 42, 77);
    assert(f.data == "\n\n\n    X = (42, 77)\n");
}
