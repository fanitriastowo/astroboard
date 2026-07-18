defmodule Astroboard.Boards.ChecklistItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "checklist_items" do
    field :content, :string
    field :done, :boolean, default: false
    field :position, :integer

    belongs_to :card, Astroboard.Boards.Card

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:content, :done])
    |> validate_required([:content])
    |> validate_length(:content, max: 500)
  end
end
