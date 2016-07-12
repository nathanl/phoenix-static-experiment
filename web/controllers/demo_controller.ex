defmodule Templater.DemoController do
  use Templater.Web, :controller

  def static(conn, _params) do
    conn
    |> put_layout(false)
    |> render
  end

  def dynamic(conn, _params) do
    conn
    |> put_layout(false)
    |> render
  end

end
