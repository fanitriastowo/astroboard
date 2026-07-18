defmodule Astroboard.Repo.Migrations.CreateChecklistItems do
  use Ecto.Migration

  def change do
    create table(:checklist_items) do
      add :content, :string, null: false
      add :done, :boolean, null: false, default: false
      add :position, :integer, null: false, default: 0
      add :card_id, references(:cards, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:checklist_items, [:card_id, :position])
  end
end
