# DHDL: The D Hardware Design Language

This is a preview of the library component of DHDL.

## Instalation

To simulate DHDL circuits you'll need to install [FIRRTL](https://github.com/freechipsproject/firrtl) and [Verilator](https://www.veripool.org/projects/verilator/wiki/Intro), as detailed below.

### Install FIRRTL:

```
git clone https://github.com/freechipsproject/firrtl.git
cd firrtl
sbt compile
sbt assembly
```

### Add FIRRTL to your path:

```
export PATH=$PATH:/path/to/firrtl/utils/bin
```

### Install Verilator

Install [Verilator](http://www.veripool.org/projects/verilator/wiki/Installing) and add it to your path.

## Execute the tests

To execute the test/demo circuit simulations, run the following command:

```
dub test
```
