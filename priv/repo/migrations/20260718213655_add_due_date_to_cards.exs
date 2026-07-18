defmodule Astroboard.Repo.Migrations.AddDueDateToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :due_date, :date
    end
  end
end
