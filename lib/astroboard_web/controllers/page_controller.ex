defmodule AstroboardWeb.PageController do
  use AstroboardWeb, :controller

  # Landing route: send authenticated users to their boards, guests to log in.
  def home(conn, _params) do
    if conn.assigns[:current_scope] do
      redirect(conn, to: ~p"/boards")
    else
      redirect(conn, to: ~p"/users/log-in")
    end
  end
end
