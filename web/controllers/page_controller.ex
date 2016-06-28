defmodule Templater.PageController do
  use Templater.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
