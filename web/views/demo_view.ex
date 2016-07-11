defmodule Templater.DemoView do
  use Templater.Web, :view
  @strings_per_page 200
  @number_of_pages 100
  @generated_pages 1..@number_of_pages |> Enum.map(fn _ ->
    Templater.StringGenerator.rand_strings @strings_per_page
  end)
  @static_page hd(@generated_pages)

  # GOAL: to have these two function heads not differ in the amount of work
  # they perform at runtime, but only in the fact that one of them returns an
  # iolist with mostly-unchanging contents, and the other returns an iolist
  # with contents that generally do change on each request. (These are sampled
  # from a pre-generated list of possible responses because otherwise we have
  # to generate random stuff at runtime, and generating this much random stuff
  # means there's a bottleneck at the step where we ask crypto for some random
  # bytes.)

  def render("static.html", _) do
    _random_page = @generated_pages |> Enum.random
    {:safe, [Templater.StringGenerator.rand_string, "\n", @static_page]}
  end

  def render("dynamic.html", _) do
    random_page = @generated_pages |> Enum.random
    {:safe, [Templater.StringGenerator.rand_string, "\n", random_page]}
  end
end
