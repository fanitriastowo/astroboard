defmodule Astroboard.Repo.Migrations.AddUserIdToBoards do
  use Ecto.Migration

  def change do
    alter table(:boards) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create index(:boards, [:user_id])
  end
end
