# General idea

This repo is an attempt to understand the following statement from "Programming Phoenix."

    "Templates are precompiled. Phoenix doesn’t need to copy strings for each rendered template. At the hardware level, you’ll see caching come into play for these strings where it never did before."

Here's my understanding so far: [Phoenix renders templates as iodata](https://github.com/phoenixframework/phoenix/blob/b7660e596efe6cd7ac711ef20172dc889f436ac2/lib/phoenix/view.ex#L334-L336), and that this means it never has to concatenate the parts of a page into a single response string. Instead, the Erlang VM can call `writev` with the iolist and let the operating system send each part of the response over the socket individually.

This means Elixir doesn't need to allocate a 2MB string in order for Phoenix to send a 2MB HTML response. That's good. But that doesn't explain the "hardware caching" part.

But I had a guess. Given that:

- `writev` is given the memory addresses in RAM of the data it should write
- a template has both static parts (like headers) and dynamic parts (eg, from a database query),
- strings are immutable in Elixir

... *maybe* hardware caching would come into play as follows:

- On first request, Phoenix renders an iolist of strings, and Cowboy calls `writev` with their memory locations.
- On Nth request, Phoenix responds with an iolist with **some of the same strings in memory** - eg, the header and footer - and these are given to `writev` as the **same memory addresses** as in the previous requests
- The operating system notices this, and says "I don't need to get that string from RAM; I already have it in CPU cache." This results in a faster response.

That was my idea. I've been trying to prove or disprove it.

##

This Phoenix app is an experiment. There are three important routes: `/static/`, `/dynamic/`, and `/tiny_template/`.

`/static/` responds using an iolist where the first element is a random string, but the rest is an unchanging list of strings.

`/dynamic/` response using an iolist that changes with each request.

Both do the same work *before* responding; they differ only in the *contents* of their response.

`/tiny_template/` renders a template with a tiny header and footer and one small dynamic string.

## Hypothesis

`/static/` may be more performant than `/dynamic/`. Because its response consists largely of the same strings, request after request, the operating system may soon say, "I'm getting a `writev` to this socket with... oh, I just saw that memory address when I sent the previous response. I can find that footer string in CPU cache and not bother with RAM."

## Testing

I used [wrk](https://github.com/wg/wrk) to load test these two endpoints. Eg:

    wrk -c2000 -t80 -d30 --timeout 10s http://localhost:4000/static
    wrk -c2000 -t80 -d30 --timeout 10s http://localhost:4000/dynamic

## Results

`/static/` was not faster, and actually looked a little slower (though that could be jitter). 🤔


===============

With "dynamic", the whole body is crammed into one string in `writev`:


      0    393                    writev:return Writev data 9/10: (416 bytes): 0x0000000017601507 \r\nx-frame-options: SAMEORIGIN\r\nx-xss-protection: 1; mode=block\r\nx-content-type-options: nosniff\r\n\r\nXGGICSJAJJMXQKQXGBFBUUKWDQPCDAUANCHXRJHLZTYNGIZYZAJVHHSNHQXSR\nOFLNFDPQWKPTORVBPFZCKDNLDEWAAKAFKAZOPHIMIQNYADAQQJYRVEKPNTZJCPQ\nQHAROKYUMMRULWJAXTFCSLCOHULOSWD

But with "static", most of the strings (though not all, curiously) are sent individually:

      0    393                    writev:return Writev data 9/16: (99 bytes): 0x000000001a606477 \r\nx-frame-options: SAMEORIGIN\r\nx-xss-protection: 1; mode=block\r\nx-content-type-options: nosni
      0    393                    writev:return Writev data 10/16: (65 bytes): 0x000000001a6025d8 KEFIOIFWOVBCBMFDFOFDTGUDMVDGTHCHLXZNZRWBFKIQTYNPDZNAXPMWFZCTITNKS
      0    393                    writev:return Writev data 11/16: (1 bytes): 0x000000001a6064da \
      0    393                    writev:return Writev data 12/16: (65 bytes): 0x000000001a602640 AQDEAMGTAIUEFOXVESOUSHNDJXTWLMWOPCCOLOZTIZHAOPXTTKQCHZLFJEIBBMTQG
      0    393                    writev:return Writev data 13/16: (128 bytes): 0x000000001a6064db \nAZKBCEXEWTOOYLJIKNUFSIVONYPYCCBAOTEVDOEUSXEGRZCCPHZVVBONYIFSMSA\nMMJWTAPGAJQRSNPFSJGDOLYDZORJJCFJTDOVUTEBKXQGPRXCFPJPLZSBQNQZN
      0    393                    writev:return Writev data 14/16: (65 bytes): 0x000000001a6026a8 OMPHAWNIYXIWOEHTVRPLDCWL
