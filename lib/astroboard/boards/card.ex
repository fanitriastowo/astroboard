defmodule Astroboard.Boards.Card do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do
    field :title, :string
    field :description, :string
    field :due_date, :date
    field :position, :integer

    belongs_to :list, Astroboard.Boards.List

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [:title, :description, :due_date])
    |> validate_required([:title])
    |> validate_length(:title, max: 240)
    |> unique_constraint(:position, name: :cards_list_id_position_index)
  end
end
