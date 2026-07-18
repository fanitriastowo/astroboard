defmodule Astroboard.BoardsTest do
  use Astroboard.DataCase, async: true

  alias Astroboard.Boards
  alias Astroboard.Boards.{Board, List, Card}

  describe "create_board/1" do
    test "creates a board with a valid title" do
      assert {:ok, %Board{} = board} = Boards.create_board(%{title: "Product Roadmap"})
      assert board.title == "Product Roadmap"
    end

    test "returns an error changeset when the title is blank" do
      assert {:error, %Ecto.Changeset{} = changeset} = Boards.create_board(%{title: ""})
      assert "can't be blank" in errors_on(changeset).title
    end
  end

  describe "create_list/2" do
    test "appends lists with incrementing positions" do
      {:ok, board} = Boards.create_board(%{title: "Board"})

      assert {:ok, %List{} = backlog} = Boards.create_list(board, %{title: "Backlog"})
      assert {:ok, %List{} = doing} = Boards.create_list(board, %{title: "Doing"})

      assert backlog.position == 0
      assert doing.position == 1
      assert backlog.board_id == board.id
    end
  end

  describe "create_card/2" do
    test "appends cards with incrementing positions within a list" do
      {:ok, board} = Boards.create_board(%{title: "Board"})
      {:ok, list} = Boards.create_list(board, %{title: "Backlog"})

      assert {:ok, %Card{} = first} = Boards.create_card(list, %{title: "First card"})
      assert {:ok, %Card{} = second} = Boards.create_card(list, %{title: "Second card"})

      assert first.position == 0
      assert second.position == 1
      assert first.list_id == list.id
    end

    test "returns an error changeset when the title is blank" do
      {:ok, board} = Boards.create_board(%{title: "Board"})
      {:ok, list} = Boards.create_list(board, %{title: "Backlog"})

      assert {:error, %Ecto.Changeset{}} = Boards.create_card(list, %{title: ""})
    end
  end

  describe "get_board!/1" do
    test "preloads lists and cards ordered by position" do
      {:ok, board} = Boards.create_board(%{title: "Board"})
      {:ok, backlog} = Boards.create_list(board, %{title: "Backlog"})
      {:ok, _doing} = Boards.create_list(board, %{title: "Doing"})
      {:ok, _c1} = Boards.create_card(backlog, %{title: "Card A"})
      {:ok, _c2} = Boards.create_card(backlog, %{title: "Card B"})

      loaded = Boards.get_board!(board.id)

      assert Enum.map(loaded.lists, & &1.title) == ["Backlog", "Doing"]
      [first_list | _] = loaded.lists
      assert Enum.map(first_list.cards, & &1.title) == ["Card A", "Card B"]
    end

    test "raises when the board does not exist" do
      assert_raise Ecto.NoResultsError, fn -> Boards.get_board!(-1) end
    end
  end
end
