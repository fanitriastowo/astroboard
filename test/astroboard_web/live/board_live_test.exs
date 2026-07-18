defmodule AstroboardWeb.BoardLiveTest do
  use AstroboardWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Astroboard.Boards

  defp create_board(%{scope: scope}) do
    {:ok, board} = Boards.create_board(scope, %{title: "Product Roadmap"})
    {:ok, backlog} = Boards.create_list(scope, board, %{title: "Backlog"})
    {:ok, _doing} = Boards.create_list(scope, board, %{title: "Doing"})
    {:ok, card} = Boards.create_card(scope, backlog, %{title: "Wire up migrations"})

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

    test "renames a board from the dashboard", %{conn: conn, board: board} do
      {:ok, view, _html} = live(conn, ~p"/boards")

      view |> element("#board-edit-#{board.id}") |> render_click()

      view
      |> form("#rename-board-#{board.id}", %{"title" => "Renamed Board"})
      |> render_submit()

      assert has_element?(view, "#boards", "Renamed Board")
      refute has_element?(view, "#boards", "Product Roadmap")
    end

    test "deletes a board from the dashboard", %{conn: conn, board: board} do
      {:ok, view, _html} = live(conn, ~p"/boards")

      view |> element("#board-delete-#{board.id}") |> render_click()

      refute has_element?(view, "#boards", "Product Roadmap")
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

  describe "List actions" do
    setup [:register_and_log_in_user, :create_board]

    test "renames a list", %{conn: conn, board: board, backlog: backlog} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}")

      view |> element("#list-edit-#{backlog.id}") |> render_click()

      view
      |> form("#rename-list-#{backlog.id}", %{"title" => "Up Next"})
      |> render_submit()

      assert has_element?(view, "#list-#{backlog.id}", "Up Next")
      refute has_element?(view, "#list-#{backlog.id}", "Backlog")
    end

    test "deletes a list", %{conn: conn, board: board, backlog: backlog} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}")

      view |> element("#list-delete-#{backlog.id}") |> render_click()

      refute has_element?(view, "#list-#{backlog.id}")
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

    test "sets a card due date shown on the card face", %{
      conn: conn,
      board: board,
      backlog: backlog,
      card: card
    } do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/cards/#{card.id}")

      view
      |> form("#card-form", %{"card" => %{"title" => card.title, "due_date" => "2026-08-01"}})
      |> render_submit()

      assert has_element?(view, "#cards-#{backlog.id}", "Aug 01")
    end

    test "deletes a card", %{conn: conn, board: board, backlog: backlog, card: card} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/cards/#{card.id}")

      view |> element("#card-delete") |> render_click()

      refute has_element?(view, "#cards-#{backlog.id}", card.title)
    end

    test "cannot open another user's card", %{conn: conn, board: board} do
      other = Astroboard.AccountsFixtures.user_scope_fixture()
      {:ok, ob} = Boards.create_board(other, %{title: "Theirs"})
      {:ok, ol} = Boards.create_list(other, ob, %{title: "L"})
      {:ok, oc} = Boards.create_card(other, ol, %{title: "secret"})

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/boards/#{board.id}/cards/#{oc.id}")
      end
    end

    test "cannot open own card under a different board's URL", %{
      conn: conn,
      scope: scope,
      card: card
    } do
      {:ok, other_board} = Boards.create_board(scope, %{title: "Other"})

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/boards/#{other_board.id}/cards/#{card.id}")
      end
    end
  end

  describe "Real-time move" do
    setup [:register_and_log_in_user]

    setup %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Move Board"})
      {:ok, list_a} = Boards.create_list(scope, board, %{title: "A"})
      {:ok, list_b} = Boards.create_list(scope, board, %{title: "B"})
      {:ok, card} = Boards.create_card(scope, list_a, %{title: "movable"})
      %{board: board, list_a: list_a, list_b: list_b, card: card}
    end

    test "moving a card across lists updates both columns", %{
      conn: conn,
      board: board,
      list_a: list_a,
      list_b: list_b,
      card: card
    } do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}")

      view
      |> element("#cards-#{list_b.id}")
      |> render_hook("move_card", %{"card_id" => card.id, "list_id" => list_b.id, "position" => 0})

      assert has_element?(view, "#cards-#{list_b.id}", "movable")
      refute has_element?(view, "#cards-#{list_a.id}", "movable")
    end

    test "ignores a move with a non-numeric card id without crashing", %{
      conn: conn,
      board: board,
      list_b: list_b
    } do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}")

      view
      |> element("#cards-#{list_b.id}")
      |> render_hook("move_card", %{
        "card_id" => "not-a-number",
        "list_id" => list_b.id,
        "position" => 0
      })

      assert has_element?(view, "#board-title")
    end
  end

  describe "Real-time cross-client" do
    setup [:register_and_log_in_user, :create_board]

    test "a new card appears live for another viewer", %{
      conn: conn,
      board: board,
      backlog: backlog
    } do
      {:ok, view_a, _html} = live(conn, ~p"/boards/#{board.id}")
      {:ok, view_b, _html} = live(conn, ~p"/boards/#{board.id}")

      view_a
      |> form("#add-card-#{backlog.id}", %{"title" => "Realtime card"})
      |> render_submit()

      assert has_element?(view_b, "#cards-#{backlog.id}", "Realtime card")
    end

    test "a renamed list appears live for another viewer", %{
      conn: conn,
      board: board,
      backlog: backlog
    } do
      {:ok, view_a, _html} = live(conn, ~p"/boards/#{board.id}")
      {:ok, view_b, _html} = live(conn, ~p"/boards/#{board.id}")

      view_a |> element("#list-edit-#{backlog.id}") |> render_click()

      view_a
      |> form("#rename-list-#{backlog.id}", %{"title" => "Renamed live"})
      |> render_submit()

      assert has_element?(view_b, "#list-#{backlog.id}", "Renamed live")
    end
  end

  describe "Members" do
    setup [:register_and_log_in_user, :create_board]

    test "owner opens the members modal with an invite form", %{conn: conn, board: board} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/members")

      assert has_element?(view, "#members-modal")
      assert has_element?(view, "#invite-form")
    end

    test "owner invites an existing user by email", %{conn: conn, board: board} do
      invitee = Astroboard.AccountsFixtures.user_scope_fixture()
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/members")

      view |> form("#invite-form", %{"email" => invitee.user.email}) |> render_submit()

      assert has_element?(view, "#members-modal", invitee.user.email)
    end

    test "inviting an unknown email shows an error", %{conn: conn, board: board} do
      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/members")

      html =
        view |> form("#invite-form", %{"email" => "nobody@example.com"}) |> render_submit()

      assert html =~ "No user"
    end

    test "owner removes a member", %{conn: conn, scope: scope, board: board} do
      invitee = Astroboard.AccountsFixtures.user_scope_fixture()
      {:ok, _} = Boards.add_member(scope, board.id, invitee.user.email)

      {:ok, view, _html} = live(conn, ~p"/boards/#{board.id}/members")
      assert has_element?(view, "#members-modal", invitee.user.email)

      view |> element("#member-remove-#{invitee.user.id}") |> render_click()

      refute has_element?(view, "#members-modal", invitee.user.email)
    end
  end

  describe "authentication" do
    test "redirects to log in when unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/boards")
      assert path =~ "/users/log-in"
    end
  end
end
