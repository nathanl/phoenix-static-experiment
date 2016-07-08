defmodule Templater.DemoView do
  use Templater.Web, :view
  @strings_per_page 200
  @number_of_pages 1_000
  @generated_pages 1..@number_of_pages |> Enum.map(fn _ ->
    Templater.StringGenerator.rand_strings @strings_per_page
  end)
  @static_page hd(@generated_pages)

  def render("static.html", _) do
    _random_page = @generated_pages |> Enum.random
    {:safe, [Templater.StringGenerator.rand_string, "\n", @static_page]}
  end

  def render("dynamic.html", _) do
    random_page = @generated_pages |> Enum.random
    {:safe, [Templater.StringGenerator.rand_string, "\n", random_page]}
  end

  # NOTE: Trying
  # wrk -c20 -t8 -d30 http://localhost:4000/dynamic
  # vs
  # wrk -c20 -t8 -d30 http://localhost:4000/static
  # Trying to have these not differ in the amount of work in the render
  # function, only differ in the fact that the OS can use CPU cache for one
  # response and not the other.
  # I expect that static will be faster, but the reverse seems true. 🤔
end
