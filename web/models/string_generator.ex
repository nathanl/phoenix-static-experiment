defmodule Templater.StringGenerator do

  :random.seed(:os.timestamp) # not good, but good enough for this

  def rand_strings(count) do
    (1..count) |> Enum.map(fn (_) -> [string_of_length(20), "\n"] end)
  end

  def rand_string do
    string_of_length(20)
  end

  def string_of_length(bytes) do
    :crypto.strong_rand_bytes(bytes) |> :base64.encode
  end

end
