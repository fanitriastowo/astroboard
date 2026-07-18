defmodule Astroboard.Repo.Migrations.CreateCardComments do
  use Ecto.Migration

  def change do
    create table(:card_comments) do
      add :body, :text, null: false
      add :card_id, references(:cards, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:card_comments, [:card_id])
  end
end
