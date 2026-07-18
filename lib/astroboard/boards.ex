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

  @doc "Creates a list appended to the end of the given board."
  def create_list(%Board{} = board, attrs) do
    attrs = Map.put(normalize(attrs), "position", next_position(List, :board_id, board.id))

    %List{board_id: board.id}
    |> List.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Renames/updates a list. Broadcasts to board subscribers on success."
  def update_list(%List{} = list, attrs) do
    case list |> List.changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        broadcast(updated.board_id, {:board_updated})
        {:ok, updated}

      error ->
        error
    end
  end

  @doc "Deletes a list and its cards. Broadcasts to board subscribers."
  def delete_list(%List{} = list) do
    case Repo.delete(list) do
      {:ok, deleted} ->
        broadcast(list.board_id, {:board_updated})
        {:ok, deleted}

      error ->
        error
    end
  end

  @doc "Creates a card appended to the end of the given list."
  def create_card(%List{} = list, attrs) do
    attrs = Map.put(normalize(attrs), "position", next_position(Card, :list_id, list.id))

    %Card{list_id: list.id}
    |> Card.changeset(attrs)
    |> Repo.insert()
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

  @doc "Updates a card's editable fields (title, description)."
  def update_card(%Card{} = card, attrs) do
    card
    |> Card.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a card."
  def delete_card(%Card{} = card) do
    Repo.delete(card)
  end

  @doc """
  Moves a card to `target_list_id` at `target_position`, reindexing the source
  and target lists so positions stay contiguous. Both the card and the target
  list must belong to the scope's user. Broadcasts `{:card_moved, card_id}` to
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

    case result do
      {:ok, moved} ->
        broadcast(target_list.board_id, {:card_moved, moved.id})
        {:ok, moved}

      other ->
        other
    end
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

  defp broadcast(board_id, message) do
    Phoenix.PubSub.broadcast(Astroboard.PubSub, topic(board_id), message)
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

  # Accept both string- and atom-keyed attrs, normalizing to string keys so we
  # can safely merge the server-computed position.
  defp normalize(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
  end
end
