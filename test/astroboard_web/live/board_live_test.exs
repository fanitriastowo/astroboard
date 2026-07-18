defmodule AstroboardWeb.BoardLiveTest do
  use AstroboardWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Astroboard.Boards

  defp create_board(_) do
    {:ok, board} = Boards.create_board(%{title: "Product Roadmap"})
    {:ok, backlog} = Boards.create_list(board, %{title: "Backlog"})
    {:ok, _doing} = Boards.create_list(board, %{title: "Doing"})
    {:ok, _card} = Boards.create_card(backlog, %{title: "Wire up migrations"})

    %{board: board, backlog: backlog}
  end

  describe "Show" do
    setup [:create_board]

    test "renders the board title, lists and cards", %{conn: conn, board: board, backlog: backlog} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}")

      assert has_element?(view, "#board-title", "Product Roadmap")
      assert has_element?(view, "#list-#{backlog.id}", "Backlog")
      assert has_element?(view, "#cards-#{backlog.id}", "Wire up migrations")
    end

    test "adds a card to a list", %{conn: conn, board: board, backlog: backlog} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}")

      view
      |> form("#add-card-#{backlog.id}", %{"title" => "Design onboarding"})
      |> render_submit()

      assert has_element?(view, "#cards-#{backlog.id}", "Design onboarding")
    end

    test "adds a list to the board", %{conn: conn, board: board} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}")

      view
      |> form("#add-list", %{"title" => "In Review"})
      |> render_submit()

      assert has_element?(view, "#board-lists", "In Review")
    end
  end
end
