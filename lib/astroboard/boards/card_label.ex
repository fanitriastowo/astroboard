defmodule Astroboard.Boards.CardLabel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "card_labels" do
    field :color, :string

    belongs_to :card, Astroboard.Boards.Card

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(card_label, attrs) do
    card_label
    |> cast(attrs, [:color])
    |> unique_constraint([:card_id, :color], name: :card_labels_card_id_color_index)
  end
end
