defmodule Astroboard.Boards.BoardMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "board_members" do
    belongs_to :board, Astroboard.Boards.Board
    belongs_to :user, Astroboard.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(board_member, attrs) do
    board_member
    |> cast(attrs, [])
    |> unique_constraint([:board_id, :user_id],
      name: :board_members_board_id_user_id_index
    )
  end
end
