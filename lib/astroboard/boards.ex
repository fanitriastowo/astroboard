defmodule Astroboard.Boards do
  @moduledoc """
  The Boards context: boards, their lists (columns), and cards.
  """

  import Ecto.Query, warn: false
  alias Astroboard.Repo
  alias Astroboard.Accounts.Scope
  alias Astroboard.Boards.{Board, List, Card}

  @doc "Lists the boards owned by the scope's user."
  def list_boards(%Scope{} = scope) do
    Repo.all(from b in Board, where: b.user_id == ^scope.user.id, order_by: [asc: b.inserted_at])
  end

  @doc """
  Returns one of the scope user's boards with its lists and cards preloaded,
  each ordered by position.

  Raises `Ecto.NoResultsError` if the board does not exist or is not owned by
  the scope's user.
  """
  def get_board!(%Scope{} = scope, id) do
    Board
    |> Repo.get_by!(id: id, user_id: scope.user.id)
    |> Repo.preload(lists: :cards)
  end

  @doc "Creates a board owned by the scope's user."
  def create_board(%Scope{} = scope, attrs) do
    %Board{user_id: scope.user.id}
    |> Board.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Creates a list appended to the end of the given board. Broadcasts on success."
  def create_list(%Scope{} = scope, %Board{} = board, attrs) do
    board_id = authorize_board!(scope, board.id)

    %List{board_id: board_id, position: next_position(List, :board_id, board_id)}
    |> List.changeset(attrs)
    |> Repo.insert()
    |> broadcast_structure(board_id)
  end

  @doc "Renames/updates a list. Broadcasts to board subscribers on success."
  def update_list(%Scope{} = scope, %List{} = list, attrs) do
    list = get_list!(scope, list.id)

    list
    |> List.changeset(attrs)
    |> Repo.update()
    |> broadcast_structure(list.board_id)
  end

  @doc "Deletes a list and its cards. Broadcasts to board subscribers."
  def delete_list(%Scope{} = scope, %List{} = list) do
    list = get_list!(scope, list.id)

    list
    |> Repo.delete()
    |> broadcast_structure(list.board_id)
  end

  @doc "Creates a card appended to the end of the given list. Broadcasts on success."
  def create_card(%Scope{} = scope, %List{} = list, attrs) do
    list = get_list!(scope, list.id)

    %Card{list_id: list.id, position: next_position(Card, :list_id, list.id)}
    |> Card.changeset(attrs)
    |> Repo.insert()
    |> broadcast_cards(list.board_id, [list.id])
  end

  @doc "Returns the scope user's cards for a list, ordered by position."
  def list_cards(%Scope{} = scope, list_id) do
    list = get_list!(scope, list_id)
    Repo.all(from c in Card, where: c.list_id == ^list.id, order_by: c.position)
  end

  @doc """
  Returns one of the scope user's cards. Raises `Ecto.NoResultsError` if the
  card does not exist or its board is not owned by the scope's user.
  """
  def get_card!(%Scope{} = scope, id) do
    Repo.one!(
      from c in Card,
        join: l in List,
        on: l.id == c.list_id,
        join: b in Board,
        on: b.id == l.board_id,
        where: c.id == ^id and b.user_id == ^scope.user.id
    )
  end

  @doc """
  Returns one of the scope user's cards that also belongs to `board_id`. Raises
  `Ecto.NoResultsError` if the card does not exist, is not owned by the scope's
  user, or lives on a different board (prevents opening a card under the wrong
  board's URL).
  """
  def get_board_card!(%Scope{} = scope, board_id, card_id) do
    Repo.one!(
      from c in Card,
        join: l in List,
        on: l.id == c.list_id,
        join: b in Board,
        on: b.id == l.board_id,
        where: c.id == ^card_id and l.board_id == ^board_id and b.user_id == ^scope.user.id
    )
  end

  @doc "Updates a card's editable fields (title, description). Broadcasts on success."
  def update_card(%Scope{} = scope, %Card{} = card, attrs) do
    card = get_card!(scope, card.id)

    card
    |> Card.changeset(attrs)
    |> Repo.update()
    |> broadcast_cards(board_id_for_card(card), [card.list_id])
  end

  @doc "Deletes a card. Broadcasts to board subscribers."
  def delete_card(%Scope{} = scope, %Card{} = card) do
    card = get_card!(scope, card.id)
    board_id = board_id_for_card(card)

    card
    |> Repo.delete()
    |> broadcast_cards(board_id, [card.list_id])
  end

  @doc """
  Moves a card to `target_list_id` at `target_position`, reindexing the source
  and target lists so positions stay contiguous. Both the card and the target
  list must belong to the scope's user. Broadcasts `{:board_updated, pid}` to
  the board's subscribers on success.
  """
  def move_card(%Scope{} = scope, card_id, target_list_id, target_position) do
    card = get_card!(scope, card_id)
    target_list = get_list!(scope, target_list_id)
    source_list_id = card.list_id
    target_position = max(target_position, 0)

    result =
      Repo.transaction(fn ->
        card = card |> Ecto.Changeset.change(list_id: target_list.id) |> Repo.update!()

        others =
          Repo.all(
            from c in Card,
              where: c.list_id == ^target_list.id and c.id != ^card.id,
              order_by: c.position,
              select: c.id
          )

        others
        |> Elixir.List.insert_at(min(target_position, length(others)), card.id)
        |> reindex()

        if source_list_id != target_list.id do
          Repo.all(
            from c in Card,
              where: c.list_id == ^source_list_id,
              order_by: c.position,
              select: c.id
          )
          |> reindex()
        end

        Repo.get!(Card, card.id)
      end)

    broadcast_cards(result, target_list.board_id, Enum.uniq([source_list_id, target_list.id]))
  end

  defp reindex(ids) do
    ids
    |> Enum.with_index()
    |> Enum.each(fn {id, index} ->
      Repo.update_all(from(c in Card, where: c.id == ^id), set: [position: index])
    end)
  end

  @doc "Returns one of the scope user's lists. Raises if not found/owned."
  def get_list!(%Scope{} = scope, id) do
    Repo.one!(
      from l in List,
        join: b in Board,
        on: b.id == l.board_id,
        where: l.id == ^id and b.user_id == ^scope.user.id
    )
  end

  ## PubSub

  @doc "Subscribes the caller to real-time updates for the given board."
  def subscribe(board_id) do
    Phoenix.PubSub.subscribe(Astroboard.PubSub, topic(board_id))
  end

  # Broadcasts tag the originating process so the acting LiveView can ignore its
  # own event (it already updated locally). Results pass through for pipelining.

  # A card-level change: subscribers restream only the affected columns.
  defp broadcast_cards({:ok, _} = result, board_id, list_ids) when not is_nil(board_id) do
    Phoenix.PubSub.broadcast(
      Astroboard.PubSub,
      topic(board_id),
      {:cards_changed, self(), list_ids}
    )

    result
  end

  defp broadcast_cards(result, _board_id, _list_ids), do: result

  # A structural change (lists added/renamed/removed): subscribers reload.
  defp broadcast_structure({:ok, _} = result, board_id) when not is_nil(board_id) do
    Phoenix.PubSub.broadcast(
      Astroboard.PubSub,
      topic(board_id),
      {:board_structure_changed, self()}
    )

    result
  end

  defp broadcast_structure(result, _board_id), do: result

  defp authorize_board!(%Scope{} = scope, board_id) do
    Repo.one!(
      from b in Board,
        where: b.id == ^board_id and b.user_id == ^scope.user.id,
        select: b.id
    )
  end

  defp board_id_for_card(%Card{list_id: list_id}) do
    Repo.one(from l in List, where: l.id == ^list_id, select: l.board_id)
  end

  defp topic(board_id), do: "board:#{board_id}"

  @doc "Returns a changeset for tracking card changes (e.g. forms)."
  def change_card(%Card{} = card, attrs \\ %{}) do
    Card.changeset(card, attrs)
  end

  @doc "Returns a changeset for tracking list changes (e.g. forms)."
  def change_list(%List{} = list, attrs \\ %{}) do
    List.changeset(list, attrs)
  end

  # Next position is the count of existing siblings (0-based, appended to the end).
  defp next_position(schema, foreign_key, parent_id) do
    Repo.one(from r in schema, where: field(r, ^foreign_key) == ^parent_id, select: count(r.id))
  end
end
