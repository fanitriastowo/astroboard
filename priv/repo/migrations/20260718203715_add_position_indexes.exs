defmodule Astroboard.Repo.Migrations.AddPositionIndexes do
  use Ecto.Migration

  # Composite indexes for ordered reads (cards/lists loaded ordered by position
  # within their parent). These supersede the standalone foreign-key indexes,
  # whose leftmost column they already cover.
  #
  # NOTE: intentionally NOT unique. move_card reindexes positions one row at a
  # time and delete_* leaves gaps that count-based next_position can reuse, both
  # of which would transiently violate a unique (parent, position) constraint
  # under SQLite's immediate uniqueness. Enforcing uniqueness needs a
  # position-management rework (append past max + reindex on delete).
  def up do
    create index(:cards, [:list_id, :position])
    create index(:lists, [:board_id, :position])

    drop_if_exists index(:cards, [:list_id])
    drop_if_exists index(:lists, [:board_id])
  end

  def down do
    create index(:cards, [:list_id])
    create index(:lists, [:board_id])

    drop index(:cards, [:list_id, :position])
    drop index(:lists, [:board_id, :position])
  end
end
