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

  describe "board membership and access" do
    setup %{scope: owner} do
      {:ok, board} = Boards.create_board(owner, %{title: "Shared"})
      {:ok, list} = Boards.create_list(owner, board, %{title: "L"})
      member = user_scope_fixture()
      %{owner: owner, board: board, list: list, member: member}
    end

    test "add_member/3 adds an existing user by email and grants access", ctx do
      %{owner: owner, board: board, member: member} = ctx
      assert {:ok, _} = Boards.add_member(owner, board.id, member.user.email)
      assert Boards.get_board!(member, board.id).id == board.id
    end

    test "add_member/3 errors for an unknown email", %{owner: owner, board: board} do
      assert {:error, :not_found} = Boards.add_member(owner, board.id, "nobody@example.com")
    end

    test "add_member/3 errors when the user is already a member", ctx do
      %{owner: owner, board: board, member: member} = ctx
      {:ok, _} = Boards.add_member(owner, board.id, member.user.email)
      assert {:error, :already_member} = Boards.add_member(owner, board.id, member.user.email)
    end

    test "add_member/3 rejects a non-owner", %{board: board, member: member} do
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Boards.add_member(member, board.id, other.user.email)
      end
    end

    test "list_boards/1 includes boards the user is a member of", ctx do
      %{owner: owner, board: board, member: member} = ctx
      {:ok, _} = Boards.add_member(owner, board.id, member.user.email)
      assert board.id in Enum.map(Boards.list_boards(member), & &1.id)
    end

    test "a non-member cannot access the board", %{board: board} do
      stranger = user_scope_fixture()
      assert_raise Ecto.NoResultsError, fn -> Boards.get_board!(stranger, board.id) end
    end

    test "a member is a full collaborator (can create cards)", ctx do
      %{owner: owner, board: board, list: list, member: member} = ctx
      {:ok, _} = Boards.add_member(owner, board.id, member.user.email)
      assert {:ok, _card} = Boards.create_card(member, list, %{title: "by member"})
    end

    test "a member cannot rename the board (owner-only)", ctx do
      %{owner: owner, board: board, member: member} = ctx
      {:ok, _} = Boards.add_member(owner, board.id, member.user.email)

      assert_raise Ecto.NoResultsError, fn ->
        Boards.update_board(member, board.id, %{title: "x"})
      end
    end

    test "remove_member/3 revokes access", ctx do
      %{owner: owner, board: board, member: member} = ctx
      {:ok, _} = Boards.add_member(owner, board.id, member.user.email)
      assert {:ok, _} = Boards.remove_member(owner, board.id, member.user.id)
      assert_raise Ecto.NoResultsError, fn -> Boards.get_board!(member, board.id) end
    end

    test "list_members/2 returns the owner and members", ctx do
      %{owner: owner, board: board, member: member} = ctx
      {:ok, _} = Boards.add_member(owner, board.id, member.user.email)
      %{owner: owner_user, members: members} = Boards.list_members(owner, board.id)

      assert owner_user.id == owner.user.id
      assert member.user.id in Enum.map(members, & &1.id)
    end
  end

  describe "update_board/3 and delete_board/2" do
    setup %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      {:ok, list} = Boards.create_list(scope, board, %{title: "L"})
      {:ok, card} = Boards.create_card(scope, list, %{title: "C"})
      %{board: board, list: list, card: card}
    end

    test "update_board/3 renames the board", %{scope: scope, board: board} do
      assert {:ok, updated} = Boards.update_board(scope, board.id, %{title: "Renamed"})
      assert updated.title == "Renamed"
    end

    test "update_board/3 rejects a blank title", %{scope: scope, board: board} do
      assert {:error, %Ecto.Changeset{}} = Boards.update_board(scope, board.id, %{title: ""})
    end

    test "update_board/3 raises for another user's board", %{board: board} do
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Boards.update_board(other, board.id, %{title: "x"})
      end
    end

    test "delete_board/2 removes the board and cascades lists and cards", %{
      scope: scope,
      board: board,
      list: list,
      card: card
    } do
      assert {:ok, _} = Boards.delete_board(scope, board.id)

      assert_raise Ecto.NoResultsError, fn -> Boards.get_board!(scope, board.id) end
      assert_raise Ecto.NoResultsError, fn -> Boards.get_list!(scope, list.id) end
      assert_raise Ecto.NoResultsError, fn -> Boards.get_card!(scope, card.id) end
    end

    test "delete_board/2 raises for another user's board", %{board: board} do
      other = user_scope_fixture()
      assert_raise Ecto.NoResultsError, fn -> Boards.delete_board(other, board.id) end
    end
  end

  describe "create_list/2 and create_card/2" do
    test "append with incrementing positions", %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})

      {:ok, backlog} = Boards.create_list(scope, board, %{title: "Backlog"})
      {:ok, doing} = Boards.create_list(scope, board, %{title: "Doing"})
      assert backlog.position == 0
      assert doing.position == 1

      {:ok, first} = Boards.create_card(scope, backlog, %{title: "First"})
      {:ok, second} = Boards.create_card(scope, backlog, %{title: "Second"})
      assert first.position == 0
      assert second.position == 1
      assert first.list_id == backlog.id
    end

    test "create_list/2 broadcasts to board subscribers", %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      Boards.subscribe(board.id)
      assert {:ok, _} = Boards.create_list(scope, board, %{title: "Backlog"})
      assert_receive {:board_structure_changed, _from}
    end

    test "create_card/2 broadcasts to board subscribers", %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      {:ok, list} = Boards.create_list(scope, board, %{title: "Backlog"})
      Boards.subscribe(board.id)
      assert {:ok, _} = Boards.create_card(scope, list, %{title: "A card"})
      assert_receive {:cards_changed, _from, _}
    end
  end

  describe "get_card!/2, update_card/2, delete_card/1" do
    setup %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      {:ok, list} = Boards.create_list(scope, board, %{title: "Backlog"})
      {:ok, card} = Boards.create_card(scope, list, %{title: "A card"})
      %{board: board, list: list, card: card}
    end

    test "get_card!/2 returns the scope user's card", %{scope: scope, card: card} do
      assert Boards.get_card!(scope, card.id).id == card.id
    end

    test "get_card!/2 raises for a card owned by another user", %{card: card} do
      other = user_scope_fixture()
      assert_raise Ecto.NoResultsError, fn -> Boards.get_card!(other, card.id) end
    end

    test "get_board_card!/3 returns the card when it belongs to the board", %{
      scope: scope,
      board: board,
      card: card
    } do
      assert Boards.get_board_card!(scope, board.id, card.id).id == card.id
    end

    test "get_board_card!/3 raises for a card on a different board of the same user", %{
      scope: scope,
      card: card
    } do
      {:ok, other_board} = Boards.create_board(scope, %{title: "Other"})

      assert_raise Ecto.NoResultsError, fn ->
        Boards.get_board_card!(scope, other_board.id, card.id)
      end
    end

    test "update_card/2 changes title and description", %{scope: scope, card: card} do
      assert {:ok, updated} =
               Boards.update_card(scope, card, %{title: "Renamed", description: "Details"})

      assert updated.title == "Renamed"
      assert updated.description == "Details"
    end

    test "update_card/2 rejects a blank title", %{scope: scope, card: card} do
      assert {:error, %Ecto.Changeset{}} = Boards.update_card(scope, card, %{title: ""})
    end

    test "update_card/2 does not let a user assign position", %{scope: scope, card: card} do
      assert {:ok, updated} = Boards.update_card(scope, card, %{title: "x", position: 99})
      assert updated.position == card.position
    end

    test "delete_card/1 removes the card", %{scope: scope, card: card} do
      assert {:ok, _} = Boards.delete_card(scope, card)
      assert_raise Ecto.NoResultsError, fn -> Boards.get_card!(scope, card.id) end
    end

    test "create_card after a delete appends past the max, never reusing a position",
         %{scope: scope, list: list, card: card} do
      {:ok, second} = Boards.create_card(scope, list, %{title: "second"})
      assert second.position == 1

      assert {:ok, _} = Boards.delete_card(scope, card)

      {:ok, third} = Boards.create_card(scope, list, %{title: "third"})
      assert third.position == 2
    end

    test "delete_card/1 broadcasts to board subscribers", %{
      scope: scope,
      board: board,
      card: card
    } do
      Boards.subscribe(board.id)
      assert {:ok, _} = Boards.delete_card(scope, card)
      assert_receive {:cards_changed, _from, _}
    end
  end

  describe "update_list/2 and delete_list/1" do
    setup %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      {:ok, list} = Boards.create_list(scope, board, %{title: "Backlog"})
      {:ok, card} = Boards.create_card(scope, list, %{title: "A card"})
      %{board: board, list: list, card: card}
    end

    test "update_list/2 renames the list", %{scope: scope, list: list} do
      assert {:ok, updated} = Boards.update_list(scope, list, %{title: "In Progress"})
      assert updated.title == "In Progress"
    end

    test "update_list/2 rejects a blank title", %{scope: scope, list: list} do
      assert {:error, %Ecto.Changeset{}} = Boards.update_list(scope, list, %{title: ""})
    end

    test "update_list/2 broadcasts to board subscribers", %{
      scope: scope,
      board: board,
      list: list
    } do
      Boards.subscribe(board.id)
      assert {:ok, _} = Boards.update_list(scope, list, %{title: "Renamed"})
      assert_receive {:board_structure_changed, _from}
    end

    test "delete_list/1 broadcasts to board subscribers", %{
      scope: scope,
      board: board,
      list: list
    } do
      Boards.subscribe(board.id)
      assert {:ok, _} = Boards.delete_list(scope, list)
      assert_receive {:board_structure_changed, _from}
    end

    test "delete_list/1 removes the list and its cards", %{
      scope: scope,
      board: board,
      list: list,
      card: card
    } do
      assert {:ok, _} = Boards.delete_list(scope, list)

      loaded = Boards.get_board!(scope, board.id)
      assert loaded.lists == []
      assert_raise Ecto.NoResultsError, fn -> Boards.get_card!(scope, card.id) end
    end
  end

  describe "move_card/4" do
    setup %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      {:ok, list_a} = Boards.create_list(scope, board, %{title: "A"})
      {:ok, list_b} = Boards.create_list(scope, board, %{title: "B"})
      {:ok, a1} = Boards.create_card(scope, list_a, %{title: "a1"})
      {:ok, a2} = Boards.create_card(scope, list_a, %{title: "a2"})
      {:ok, a3} = Boards.create_card(scope, list_a, %{title: "a3"})
      {:ok, b1} = Boards.create_card(scope, list_b, %{title: "b1"})

      %{board: board, list_a: list_a, list_b: list_b, a1: a1, a2: a2, a3: a3, b1: b1}
    end

    test "reorders a card within its list", %{scope: scope, list_a: list_a, a1: a1} do
      assert {:ok, _} = Boards.move_card(scope, a1.id, list_a.id, 2)

      board = Boards.get_board!(scope, list_a.board_id)
      cards = Enum.find(board.lists, &(&1.id == list_a.id)).cards
      assert Enum.map(cards, & &1.title) == ["a2", "a3", "a1"]
      assert Enum.map(cards, & &1.position) == [0, 1, 2]
    end

    test "moves a card to another list at a position", %{
      scope: scope,
      list_a: list_a,
      list_b: list_b,
      a1: a1
    } do
      assert {:ok, _} = Boards.move_card(scope, a1.id, list_b.id, 0)

      board = Boards.get_board!(scope, list_a.board_id)
      a_cards = Enum.find(board.lists, &(&1.id == list_a.id)).cards
      b_cards = Enum.find(board.lists, &(&1.id == list_b.id)).cards

      assert Enum.map(a_cards, & &1.title) == ["a2", "a3"]
      assert Enum.map(a_cards, & &1.position) == [0, 1]
      assert Enum.map(b_cards, & &1.title) == ["a1", "b1"]
      assert Enum.map(b_cards, & &1.position) == [0, 1]
    end

    test "broadcasts to board subscribers", %{scope: scope, board: board, list_b: list_b, a1: a1} do
      Boards.subscribe(board.id)
      assert {:ok, _} = Boards.move_card(scope, a1.id, list_b.id, 0)
      assert_receive {:cards_changed, _from, _}
    end

    test "raises for another user's card", %{list_a: list_a, a1: a1} do
      other = user_scope_fixture()
      assert_raise Ecto.NoResultsError, fn -> Boards.move_card(other, a1.id, list_a.id, 0) end
    end
  end

  describe "get_board!/2" do
    test "preloads lists and cards ordered by position", %{scope: scope} do
      {:ok, board} = Boards.create_board(scope, %{title: "Board"})
      {:ok, backlog} = Boards.create_list(scope, board, %{title: "Backlog"})
      {:ok, _doing} = Boards.create_list(scope, board, %{title: "Doing"})
      {:ok, _c1} = Boards.create_card(scope, backlog, %{title: "Card A"})
      {:ok, _c2} = Boards.create_card(scope, backlog, %{title: "Card B"})

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
