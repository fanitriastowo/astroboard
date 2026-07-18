defmodule Astroboard.Repo.Migrations.CreateCardLabels do
  use Ecto.Migration

  def change do
    create table(:card_labels) do
      add :color, :string, null: false
      add :card_id, references(:cards, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:card_labels, [:card_id, :color])
  end
end
