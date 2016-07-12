# General idea

This repo is an attempt to understand the following statement from "Programming Phoenix."

> "Templates are precompiled. Phoenix doesn’t need to copy strings for each rendered template. At the hardware level, you’ll see caching come into play for these strings where it never did before."

I wanted to know: where, exactly, does hardware caching come into play, and how does it help performance?

After reading [Elixir RAM and the Template of Doom](http://www.evanmiller.org/elixir-ram-and-the-template-of-doom.html) and looking at the Phoenix source, I had some ideas.

Here's my understanding so far: [Phoenix renders templates as iodata](https://github.com/phoenixframework/phoenix/blob/b7660e596efe6cd7ac711ef20172dc889f436ac2/lib/phoenix/view.ex#L334-L336), and this means it never has to concatenate the parts of a page into a single response string. Instead, the Erlang VM can call `writev` with the flattened iolist and let the operating system concatenate the response to be sent over TCP.

This means the BEAM doesn't need to allocate a 200MB string in order for Phoenix to send a 200MB HTML response. That's good. But that doesn't explain the "hardware caching" part.

But I had a guess. Given that:

- `writev` is given the memory addresses in RAM of the items it should write
- a template has both static parts (like headers) and dynamic parts (eg, from a database query),
- strings are immutable in Elixir

... *maybe* hardware caching would come into play as follows:

- On first request, Phoenix renders an iolist of strings, and Cowboy calls `writev` with their memory locations.
- On Nth request, Phoenix responds with an iolist with **some of the same strings in memory** - eg, the header and footer - and these are given to `writev` as the **same memory addresses** as in the previous requests
- The operating system notices this, and says "I don't need to get that string from RAM; I already have it in CPU cache." This results in a faster response.

That was my hypothesis. I've been trying to prove or disprove it.

## What I tried

I wrote a Phoenix app with two endpoints: `/dynamic/` and `/static/`. Both `render` functions return an iolist of pre-generated random strings, and both do the same amount of work at runtime. The only difference is that `dynamic` responds with a random selection of the pre-generated strings and `static` responds with mostly the same ones.

I ran this Phoenix app and used [Evan Miller's dtrace script](https://github.com/evanmiller/tracewrite) to watch it, like `sudo dtrace -s tracewrite.d -p 33924`.

## What I found

Sure enough, after much futzing with the size of the strings (see notes in `StringGenerator` if you care), I saw that `/static/` uses the same memory addresses for some of the strings it sends to `writev`, request after request. For example, I saw this line in the dtrace output for several requests in a row:
                                   
    Writev data 10/11: (65 bytes): 0x00000000169b5db8 GZKHIIYQPVYQKYPTVCDGJIES
                             memory address--^  for   ^-- this string, which appears in the HTML

(I also saw the same memory addresses for the strings rendered from a template, assuming they were the right size - for example, with this one:

    <header>O O O O O O O O O O O O O O O O O O O O O O O O O O O O O O O O</header>
    <%= "time: #{:os.system_time(:milli_seconds)}" %>
    <footer>X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X</footer>

)

On the other hand, `/dyanmic` would cram the whole response into one of the vector elements sent to `writev`.

However, surprisingly, the `/static/` endpoint has **lower throughput** than `/dynamic/`.

    $: wrk -c800 -t80 -d30 --timeout 10s http://localhost:4000/static
    Running 30s test @ http://localhost:4000/static
      80 threads and 800 connections
      Thread Stats   Avg      Stdev     Max   +/- Stdev
        Latency   338.55ms  124.75ms 769.10ms   67.02%
        Req/Sec    29.28     19.27   101.00     57.02%
      64042 requests in 30.10s, 43.28MB read
      Socket errors: connect 0, read 727, write 0, timeout 0
    Requests/sec:   2127.42
    Transfer/sec:      1.44MB

    $: wrk -c800 -t80 -d30 --timeout 10s http://localhost:4000/dynamic
    Running 30s test @ http://localhost:4000/dynamic
      80 threads and 800 connections
      Thread Stats   Avg      Stdev     Max   +/- Stdev
        Latency   322.74ms  119.46ms 734.58ms   67.82%
        Req/Sec    29.69     19.51   101.00     59.45%
      61371 requests in 30.09s, 41.83MB read
      Socket errors: connect 0, read 913, write 0, timeout 0
    Requests/sec:   2039.34
    Transfer/sec:      1.39MB

This actually matches what Evan Miller describes in [Elixir RAM and the Template of Doom](http://www.evanmiller.org/elixir-ram-and-the-template-of-doom.html). He shows that if you mess with your output so that `writev` gets fewer, larger items, the response time is faster. He describes this as it being "delivered to the client" in differently-sized "chunks", but I'm not sure what that means: the response does not used chunked encoding, and the entire response comes back in a single TCP packet, according to Wireshark.

In any case, it appears that `writev` itself is faster if given fewer, larger items in the vector. Apparently this effect is larger than the effect (if any) of CPU caching in getting these strings from memory.

So: it appears that hardware caching is not a significant performance factor in my tests (though I could be doing something wrong).

Maybe there's some other place I'm not thinking of where hardware caching comes into play?
