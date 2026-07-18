defmodule AstroboardWeb.BoardLive.Index do
  use AstroboardWeb, :live_view

  alias Astroboard.Boards

  @impl true
  def mount(_params, _session, socket) do
    boards = Boards.list_boards(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Your boards")
     |> stream(:boards, boards)}
  end

  @impl true
  def handle_event("create_board", %{"title" => title}, socket) do
    case Boards.create_board(socket.assigns.current_scope, %{title: title}) do
      {:ok, board} ->
        {:noreply, stream_insert(socket, :boards, board, at: -1)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex items-center gap-3">
          <span class="size-8 rounded-lg bg-gradient-to-br from-violet-500 to-cyan-400 shadow-lg shadow-violet-500/40" />
          <h1 class="text-2xl font-bold tracking-tight">Your boards</h1>
        </header>

        <ul id="boards" phx-update="stream" class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <li
            :for={{dom_id, board} <- @streams.boards}
            id={dom_id}
            class="rounded-xl border border-base-300 bg-base-200/60 hover:border-violet-400 transition-colors"
          >
            <.link navigate={~p"/boards/#{board.id}"} class="block p-4 h-24 flex items-end">
              <span class="font-semibold">{board.title}</span>
            </.link>
          </li>
        </ul>

        <form id="new-board-form" phx-submit="create_board" class="flex gap-2 max-w-sm">
          <input
            type="text"
            name="title"
            autocomplete="off"
            placeholder="New board title"
            class="input input-bordered w-full text-sm"
          />
          <button type="submit" class="btn btn-primary btn-sm">Create board</button>
        </form>
      </div>
    </Layouts.app>
    """
  end
end
