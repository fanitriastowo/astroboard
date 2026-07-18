defmodule Astroboard.Repo.Migrations.CreateBoardsListsCards do
  use Ecto.Migration

  def change do
    create table(:boards) do
      add :title, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:lists) do
      add :title, :string, null: false
      add :position, :integer, null: false, default: 0
      add :board_id, references(:boards, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:lists, [:board_id])

    create table(:cards) do
      add :title, :string, null: false
      add :position, :integer, null: false, default: 0
      add :list_id, references(:lists, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:cards, [:list_id])
  end
end
