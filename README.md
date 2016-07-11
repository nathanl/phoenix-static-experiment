# General idea

This Phoenix app is an experiment. There are two important routes: `/static/` and `/dynamic/`.

- `/static/` responds using an iolist where the first element is a random string, but the rest is an unchanging list of strings.
- `/dynamic/` response using an iolist that changes with each request.

Both do the same work *before* responding; they differ only in the *contents* of their respond.

## Hypothesis

`/static/` may be more performant. Because its response consists largely of the same strings, request after request, the operating system may soon say, "I'm getting a `writev` to this socket with... oh, I just saw that memory address when I sent the previous response. I can find that footer string in CPU cache and not bother with RAM."

## Testing

I used [wrk](https://github.com/wg/wrk) to load test these two endpoints. Eg:

    wrk -c2000 -t80 -d30 --timeout 10s http://localhost:4000/static
    wrk -c2000 -t80 -d30 --timeout 10s http://localhost:4000/dynamic

## Results

`/static/` was not faster, and actually looked a little slower (though that could be jitter). 🤔
