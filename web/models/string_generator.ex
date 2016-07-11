defmodule Templater.StringGenerator do
  # > 64 bytes so strings will be refcounted, non-heap.
  # This means it can be shared (not copied) across processes - this one and the cowboy process.
  # And that in turn should mean that it can be referenced in the same memory location in
  # subsequent calls to writev on the socket
  @default_length 65
  @chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.split("")

  def rand_strings(count) do
    (1..count) |> Enum.map(fn (_) -> [string_of_length(@default_length), "\n"] end)
  end

  def rand_string do
    string_of_length(@default_length)
  end

  def string_of_length(length) do
    Enum.reduce((1..length), "", fn (_i, acc) ->
      new_char = @chars |> Enum.random
      acc <> new_char
    end)
  end

end
