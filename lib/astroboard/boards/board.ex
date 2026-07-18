defmodule Astroboard.Boards.Board do
  use Ecto.Schema
  import Ecto.Changeset

  schema "boards" do
    field :title, :string

    belongs_to :user, Astroboard.Accounts.User
    has_many :lists, Astroboard.Boards.List, preload_order: [asc: :position]
    has_many :board_members, Astroboard.Boards.BoardMember

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(board, attrs) do
    board
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> validate_length(:title, max: 120)
  end
end
