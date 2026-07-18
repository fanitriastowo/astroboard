# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Astroboard.Repo.insert!(%Astroboard.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Astroboard.Boards

if Boards.list_boards() == [] do
  {:ok, board} = Boards.create_board(%{title: "Product Roadmap"})

  seed_lists = [
    {"Backlog", ["Wire up SQLite migrations", "Research drag-and-drop", "Sketch empty states"]},
    {"In Progress", ["Build Board LiveView with streams", "Card detail modal + PubSub"]},
    {"In Review", ["Auth: login, signup, session"]},
    {"Done", ["Scaffold Phoenix app + SQLite repo", "Set up Bandit + Req + esbuild"]}
  ]

  for {list_title, card_titles} <- seed_lists do
    {:ok, list} = Boards.create_list(board, %{title: list_title})
    for card_title <- card_titles, do: {:ok, _} = Boards.create_card(list, %{title: card_title})
  end

  IO.puts("Seeded demo board at /boards/#{board.id}")
end
