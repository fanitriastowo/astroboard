defmodule Astroboard.Repo.Migrations.MakePositionIndexesUnique do
  use Ecto.Migration

  # Enforce unique positions within a parent now that position management keeps
  # them contiguous (append-past-max on create, collision-free reindex on move).
  def up do
    drop index(:cards, [:list_id, :position])
    drop index(:lists, [:board_id, :position])

    create unique_index(:cards, [:list_id, :position])
    create unique_index(:lists, [:board_id, :position])
  end

  def down do
    drop index(:cards, [:list_id, :position])
    drop index(:lists, [:board_id, :position])

    create index(:cards, [:list_id, :position])
    create index(:lists, [:board_id, :position])
  end
end
