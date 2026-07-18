defmodule AstroboardWeb.BoardLive do
  use AstroboardWeb, :live_view

  alias Astroboard.Boards

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    board = Boards.get_board!(socket.assigns.current_scope, id)

    socket =
      socket
      |> assign(:page_title, board.title)
      |> assign(:board, board)
      |> assign(:lists, board.lists)

    socket =
      Enum.reduce(board.lists, socket, fn list, acc ->
        stream(acc, stream_name(list.id), list.cards)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("add_card", %{"list_id" => list_id, "title" => title}, socket) do
    list = Enum.find(socket.assigns.lists, &(to_string(&1.id) == to_string(list_id)))

    case list && Boards.create_card(list, %{title: title}) do
      {:ok, card} ->
        {:noreply, stream_insert(socket, stream_name(list.id), card)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("add_list", %{"title" => title}, socket) do
    case Boards.create_list(socket.assigns.board, %{title: title}) do
      {:ok, list} ->
        {:noreply,
         socket
         |> update(:lists, &(&1 ++ [%{list | cards: []}]))
         |> stream(stream_name(list.id), [])}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  defp stream_name(list_id), do: :"cards_#{list_id}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/boards"}
            class="text-sm text-base-content/50 hover:text-base-content transition-colors"
          >
            &larr; Boards
          </.link>
          <span class="cosmic-badge size-8 rounded-xl" />
          <h1 id="board-title" class="text-2xl font-bold tracking-tight">{@board.title}</h1>
        </header>

        <div id="board-lists" class="flex gap-4 overflow-x-auto pb-4 items-start">
          <section
            :for={list <- @lists}
            id={"list-#{list.id}"}
            class="glass-panel flex-none w-72 rounded-2xl p-3 space-y-3"
          >
            <div class="flex items-center justify-between px-1">
              <h2 class="text-sm font-semibold">{list.title}</h2>
            </div>

            <div id={"cards-#{list.id}"} phx-update="stream" class="space-y-2">
              <article
                :for={{dom_id, card} <- @streams[stream_name(list.id)]}
                id={dom_id}
                class="card-cosmic rounded-xl px-3 py-2.5 text-sm cursor-pointer"
              >
                {card.title}
              </article>
            </div>

            <form
              id={"add-card-#{list.id}"}
              phx-submit="add_card"
              phx-value-list_id={list.id}
              class="flex gap-2"
            >
              <input
                type="text"
                name="title"
                autocomplete="off"
                placeholder="+ Add a card"
                class="input input-sm input-bordered w-full text-sm bg-base-100/40"
              />
            </form>
          </section>

          <form
            id="add-list"
            phx-submit="add_list"
            class="flex-none w-72 rounded-2xl border border-dashed border-base-300 p-3"
          >
            <input
              type="text"
              name="title"
              autocomplete="off"
              placeholder="+ Add another list"
              class="input input-sm input-bordered w-full text-sm bg-transparent"
            />
          </form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
