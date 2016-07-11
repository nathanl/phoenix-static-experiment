defmodule Templater.Router do
  use Templater.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Templater do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index

    get "/dynamic",       DemoController, :dynamic
    get "/tiny_template", DemoController, :tiny_template
    get "/hardcoded",     DemoController, :hardcoded
    get "/static",        DemoController, :static
  end

  # Other scopes may use custom stacks.
  # scope "/api", Templater do
  #   pipe_through :api
  # end
end
