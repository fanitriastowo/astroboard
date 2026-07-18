defmodule Astroboard.Boards.CardComment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "card_comments" do
    field :body, :string

    belongs_to :card, Astroboard.Boards.Card
    belongs_to :user, Astroboard.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, max: 2000)
  end
end
