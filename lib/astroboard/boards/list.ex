defmodule Astroboard.Boards.List do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lists" do
    field :title, :string
    field :position, :integer

    belongs_to :board, Astroboard.Boards.Board
    has_many :cards, Astroboard.Boards.Card, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(list, attrs) do
    list
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> validate_length(:title, max: 120)
    |> unique_constraint(:position, name: :lists_board_id_position_index)
  end
end
