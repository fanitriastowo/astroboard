defmodule AstroboardWeb.PageController do
  use AstroboardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
