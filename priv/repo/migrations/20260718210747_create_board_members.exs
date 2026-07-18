defmodule Astroboard.Repo.Migrations.CreateBoardMembers do
  use Ecto.Migration

  def change do
    create table(:board_members) do
      add :board_id, references(:boards, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:board_members, [:board_id, :user_id])
    create index(:board_members, [:user_id])
  end
end
