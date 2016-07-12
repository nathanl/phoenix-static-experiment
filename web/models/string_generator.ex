defmodule Templater.StringGenerator do
  # How does @default_length affect what gets written on the socket via `writev`?
  #
  # At < 64 bytes, these are all combined in writev, possibly because they're too small to be refcounted strings,
  # and are therefore copied across process boundaries.
  # 
  # At 66 bytes, they will be refecounted, non-heap strings. This means they can be shared between the Phoenix and Cowboy processes using the same address in RAM. On inspection, some are sent individually and some combined. When sent individually, they reference the same memory location in repeated requests. This could mean they benefit from from CPU cache, but it also means the response gets sent to the client in smaller chunks, according to http://www.evanmiller.org/elixir-ram-and-the-template-of-doom.html (not sure exactly what this means, since it's not chunked encoding, but perhaps it means "more tcp packets" - the max that can fit in a TCP packet is much more than this - http://stackoverflow.com/questions/2613734/maximum-packet-size-for-a-tcp-connection).
  # Nope it doesn't mean that - the whole HTTP response goes in one packet.
  # At this size, the /static endpoint is slower than /dynamic, which is what we'd expect based on "Template of Doom"
  #
  # At > 512 bytes, every one of these is a separate item in the vector given to `writev` - ERL_ONHEAP_BIN_LIMIT says they're too large to combine.
  #
  # Overall, there's a tradeoff between memory usage and speed of response, which is made by the VM, maybe not optimally, but probably it's not something most users will care about or know how to best optimize and should leave to it.
  @default_length 66

  @chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.split("")

  def rand_strings(count) do
    (1..count) |> Enum.map(fn (_) -> [string_of_length(@default_length), "\n"] end)
  end

  def rand_string do
    string_of_length(@default_length)
  end

  def string_of_length(length) do
    Enum.reduce((1..length), [], fn (_i, acc) ->
      [Enum.random(@chars) | acc]
    end) |> Enum.join("")
  end

end
# Writev data 10/11: (65 bytes): 0x00000000169b5db8 GZKHIIYQPVYQKYPTVCDGJIES
