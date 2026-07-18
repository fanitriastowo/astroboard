defmodule Astroboard.BoardsTest do
  use Astroboard.DataCase, async: true

  import Astroboard.AccountsFixtures

  alias Astroboard.Boards
  alias Astroboard.Boards.Board

  setup do
    %{scope: user_scope_fixture()}
  end

  describe "create_board/2" do
    test "creates a board owned by the scope's user", %{scope: scope} do
      assert {:ok, %Board{} = board} = Boards.create_board(scope, %{title: "Product Roadmap"})
      assert board.title == "Product Roadmap"
      assert board.user_id == scope.user.id
    end

    test "returns an error changeset when the title is blank", %{scope: scope} do
      assert {:error, %Ecto.Changeset{} = changeset} = Boards.create_board(scope, %{title: ""})
      assert "can't be blank" in errors_on(changeset).title
    end
  end

  describe "list_boards/1" do
    test "only returns boards owned by the scope's user", %{scope: scope} do
      {:ok, mine} = Boards.create_board(scope, %{title: "Mine"})
      other_scope = user_scope_fixture()
      {:ok, _theirs} = Boards.create_board(other_scope, %{title: "Theirs"})

      assert Enum.map(Boards.list_boards(scope), & &1.id) == [mine.id]
    end
  end

  describe "create_list/2 and create_card/2" do
    test "append with incrementing positions", %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})

      {:ok, backlog} = Boards.create_list(board, %{title: "Backlog"})
      {:ok, doing} = Boards.create_list(board, %{title: "Doing"})
      assert backlog.position == 0
      assert doing.position == 1

      {:ok, first} = Boards.create_card(backlog, %{title: "First"})
      {:ok, second} = Boards.create_card(backlog, %{title: "Second"})
      assert first.position == 0
      assert second.position == 1
      assert first.list_id == backlog.id
    end
  end

  describe "get_board!/2" do
    test "preloads lists and cards ordered by position", %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      {:ok, backlog} = Boards.create_list(board, %{title: "Backlog"})
      {:ok, _doing} = Boards.create_list(board, %{title: "Doing"})
      {:ok, _c1} = Boards.create_card(backlog, %{title: "Card A"})
      {:ok, _c2} = Boards.create_card(backlog, %{title: "Card B"})

      loaded = Boards.get_board!(scope, board.id)

      assert Enum.map(loaded.lists, & &1.title) == ["Backlog", "Doing"]
      [first_list | _] = loaded.lists
      assert Enum.map(first_list.cards, & &1.title) == ["Card A", "Card B"]
    end

    test "raises when the board is owned by another user", %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      other_scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn -> Boards.get_board!(other_scope, board.id) end
    end
  end
end
