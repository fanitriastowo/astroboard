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

  @doc "Creates a card appended to the end of the given list."
  def create_card(%List{} = list, attrs) do
    attrs = Map.put(normalize(attrs), "position", next_position(Card, :list_id, list.id))

    %Card{list_id: list.id}
    |> Card.changeset(attrs)
    |> Repo.insert()
  end

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
