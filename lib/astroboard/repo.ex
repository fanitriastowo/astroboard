defmodule Astroboard.Repo do
  use Ecto.Repo,
    otp_app: :astroboard,
    adapter: Ecto.Adapters.SQLite3
end
