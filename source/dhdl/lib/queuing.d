/+
This is a DHDL test library. You generally wouldn't write this D code by hand.
Instead, you would write DHDL code and the DHDL compiler would generate the
code you see in this module.
+/

module dhdl.lib.queuing;

import std.stdio;
import dhdl;
import dhdl.lib.coupling;
import dhdl.testing;
import openmethods;

class Queue(T, int entries) : Circuit
{
    @in_ ReadyValid!T enq;
    @out_ ReadyValid!T deq;
    @out_ UInt!(entries.widthOf) count;

    this(bool pipe = false, bool flow = false)
    {
        this.instantiate!enq;
        this.instantiate!deq;
        this.instantiate!count;

        assert(entries >= 1);

        Mem ram;
        this.instantiate!ram(new T, entries, false);

        Reg enqPtr;
        this.instantiate!enqPtr(0.U!(entries.widthOf));

        Reg deqPtr;
        this.instantiate!deqPtr(0.U!(entries.widthOf));

        Reg maybeFull;
        this.instantiate!maybeFull(false.B);

        auto ptrMatch = enqPtr.eq(deqPtr);
        auto empty = ptrMatch & (maybeFull.not);
        auto full = ptrMatch & maybeFull;

        Wire doEnq;
        this.instantiate!doEnq(new Bool);
        this.connect(doEnq, enq.ready & enq.valid);

        Wire doDeq;
        this.instantiate!doDeq(new Bool);
        this.connect(doDeq, deq.ready & deq.valid);

        when(doEnq,
        {
            this.connect(ram[enqPtr], enq.payload);

            when(enqPtr.eq((entries-1).U),
            {
                this.connect(enqPtr, 0.U);
            },
            {
                this.connect(enqPtr, enqPtr + 1.U);
            });
        });

        when(doDeq,
        {
            when(deqPtr.eq((entries-1).U),
            {
                this.connect(deqPtr, 0.U);
            },
            {
                this.connect(deqPtr, deqPtr + 1.U);
            });
        });

        when(doEnq.neq(doDeq),
        {
            this.connect(maybeFull, doEnq);
        });

        this.connect(deq.valid, empty.not);
        this.connect(enq.ready, full.not);
        this.connect(deq.payload, ram[deqPtr]);

        if(flow)
        {
            when(enq.valid,
            {
                this.connect(deq.valid, true.B);
            });

            when(empty,
            {
                this.connect(deq.payload, enq.payload);
                this.connect(doDeq, false.B);
                
                when(deq.ready,
                {
                    this.connect(doEnq, false.B);
                });
            });
        }

        if(pipe)
        {
            when(deq.ready,
            {
                this.connect(enq.ready, true.B);
            });
        }

        this.connect(count, (maybeFull & ptrMatch) ~ (enqPtr - deqPtr)[entries.widthOf-1 .. 0]);
    }
}

version(HWTests) unittest
{
    alias C = Queue!(UInt!16, 8);
    auto queue = peekPokeTester!C(false, false);

    assert(queue.count == 0);
    assert(queue.enq.ready == true);
    assert(queue.deq.valid == false);

    queue.enq.valid = true;

    foreach(i; 0 .. 8)
        queue.step();

    assert(queue.count == 8);
    assert(queue.enq.ready == false);

    queue.enq.valid = false;
    queue.deq.ready = true;

    while(queue.count > 0)
        queue.step();

    assert(queue.enq.ready == true);
    assert(queue.deq.valid == false);

    queue.enq.valid = true;
    queue.deq.ready = false;

    queue.enq.payload = 42;
    queue.step();
    assert(queue.count == 1);

    queue.enq.payload = 43;
    queue.step();
    assert(queue.count == 2);

    queue.enq.valid = false;
    queue.deq.ready = true;

    queue.eval();
    assert(queue.deq.payload == 42);

    queue.step();
    assert(queue.count == 1);
    assert(queue.deq.payload == 43);

    queue.step();
    assert(queue.count == 0);
}
