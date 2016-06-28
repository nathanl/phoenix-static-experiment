defmodule Templater.DemoView do
  use Templater.Web, :view
  @how_many 20
  @static_page Templater.StringGenerator.rand_strings(@how_many)

  def render("static.html", _) do
    dp = dynamic_page
    {:safe, ["hi\n"|@static_page]}
  end

  def render("dynamic.html", _) do
    dp = dynamic_page
    {:safe, ["hi\n"|dp]}
  end

  defp dynamic_page do
    Templater.StringGenerator.rand_strings(@how_many)
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
