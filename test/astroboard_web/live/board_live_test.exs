defmodule AstroboardWeb.BoardLiveTest do
  use AstroboardWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Astroboard.Boards

  defp create_board(%{scope: scope}) do
    {:ok, board} = Boards.create_board(scope, %{title: "Product Roadmap"})
    {:ok, backlog} = Boards.create_list(board, %{title: "Backlog"})
    {:ok, _doing} = Boards.create_list(board, %{title: "Doing"})
    {:ok, card} = Boards.create_card(backlog, %{title: "Wire up migrations"})

    %{board: board, backlog: backlog, card: card}
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_board]

    test "lists the current user's boards", %{conn: conn, board: board} do
      {:ok, view, _html} = live(conn, ~p"/boards")

      assert has_element?(view, "#boards", board.title)
    end

    test "does not list boards owned by other users", %{conn: conn} do
      other = Astroboard.AccountsFixtures.user_scope_fixture()
      {:ok, _theirs} = Boards.create_board(other, %{title: "Secret Board"})

      {:ok, view, _html} = live(conn, ~p"/boards")

      refute has_element?(view, "#boards", "Secret Board")
    end

    test "creates a board from the index", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/boards")

      view
      |> form("#new-board-form", %{"title" => "Q3 Launch"})
      |> render_submit()

      assert has_element?(view, "#boards", "Q3 Launch")
    end
  end

  describe "Show" do
    setup [:register_and_log_in_user, :create_board]

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

    test "cannot view another user's board", %{conn: conn} do
      other = Astroboard.AccountsFixtures.user_scope_fixture()
      {:ok, theirs} = Boards.create_board(other, %{title: "Theirs"})

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/boards/#{theirs.id}") end
    end
  end

  describe "Card modal" do
    setup [:register_and_log_in_user, :create_board]

    test "opens the card modal from its URL", %{conn: conn, board: board, card: card} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/cards/#{card.id}")

      assert has_element?(view, "#card-modal")
      assert has_element?(view, ~s(#card-form input[name="card[title]"][value="#{card.title}"]))
    end

    test "updates a card and reflects the new title on the board", %{
      conn: conn,
      board: board,
      backlog: backlog,
      card: card
    } do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/cards/#{card.id}")

      view
      |> form("#card-form", %{
        "card" => %{"title" => "Renamed card", "description" => "Some notes"}
      })
      |> render_submit()

      assert has_element?(view, "#cards-#{backlog.id}", "Renamed card")
      refute has_element?(view, "#card-modal")
    end

    test "deletes a card", %{conn: conn, board: board, backlog: backlog, card: card} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/cards/#{card.id}")

      view |> element("#card-delete") |> render_click()

      refute has_element?(view, "#cards-#{backlog.id}", card.title)
    end

    test "cannot open another user's card", %{conn: conn, board: board} do
      other = Astroboard.AccountsFixtures.user_scope_fixture()
      {:ok, ob} = Boards.create_board(other, %{title: "Theirs"})
      {:ok, ol} = Boards.create_list(ob, %{title: "L"})
      {:ok, oc} = Boards.create_card(ol, %{title: "secret"})

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/boards/#{board.id}/cards/#{oc.id}")
      end
    end
  end

  describe "authentication" do
    test "redirects to log in when unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/boards")
      assert path =~ "/users/log-in"
    end
  end
end
