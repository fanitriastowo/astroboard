defmodule AstroboardWeb.BoardLive.Index do
  use AstroboardWeb, :live_view

  alias Astroboard.Boards

  @impl true
  def mount(_params, _session, socket) do
    boards = Boards.list_boards(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Your boards")
     |> assign(:editing_board_id, nil)
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

  def handle_event("edit_board", %{"board_id" => board_id}, socket) do
    board = Boards.get_owned_board!(socket.assigns.current_scope, to_int(board_id))

    # Re-stream the board so the tile re-renders in edit mode (streamed items
    # don't re-render on a plain assign change).
    {:noreply,
     socket
     |> assign(:editing_board_id, board.id)
     |> stream_insert(:boards, board)}
  end

  def handle_event("cancel_edit_board", _params, socket) do
    socket =
      case socket.assigns.editing_board_id do
        nil ->
          socket

        board_id ->
          board = Boards.get_owned_board!(socket.assigns.current_scope, board_id)
          stream_insert(socket, :boards, board)
      end

    {:noreply, assign(socket, :editing_board_id, nil)}
  end

  def handle_event("rename_board", %{"board_id" => board_id, "title" => title}, socket) do
    case Boards.update_board(socket.assigns.current_scope, to_int(board_id), %{title: title}) do
      {:ok, board} ->
        {:noreply,
         socket
         |> assign(:editing_board_id, nil)
         |> stream_insert(:boards, board)}

      {:error, _changeset} ->
        {:noreply, assign(socket, :editing_board_id, nil)}
    end
  end

  def handle_event("delete_board", %{"board_id" => board_id}, socket) do
    {:ok, board} = Boards.delete_board(socket.assigns.current_scope, to_int(board_id))
    {:noreply, stream_delete(socket, :boards, board)}
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex items-center gap-3">
          <span class="cosmic-badge size-8 rounded-xl" />
          <h1 class="text-2xl font-bold tracking-tight">Your boards</h1>
        </header>

        <ul id="boards" phx-update="stream" class="grid grid-cols-2 sm:grid-cols-3 gap-4">
          <li
            :for={{dom_id, board} <- @streams.boards}
            id={dom_id}
            class="card-cosmic rounded-2xl overflow-hidden group relative"
          >
            <span class="block h-16 cosmic-badge opacity-80"></span>
            <div class="p-4">
              <%= if @editing_board_id == board.id do %>
                <form
                  id={"rename-board-#{board.id}"}
                  phx-submit="rename_board"
                  phx-value-board_id={board.id}
                >
                  <input
                    type="text"
                    name="title"
                    value={board.title}
                    autocomplete="off"
                    phx-mounted={JS.focus()}
                    phx-blur="cancel_edit_board"
                    class="input input-xs input-bordered w-full text-sm bg-base-100/40"
                  />
                </form>
              <% else %>
                <.link navigate={~p"/boards/#{board.id}"} class="font-semibold hover:text-primary">
                  {board.title}
                </.link>
              <% end %>
            </div>

            <div class="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <button
                type="button"
                id={"board-edit-#{board.id}"}
                phx-click="edit_board"
                phx-value-board_id={board.id}
                class="rounded-md bg-base-300/70 p-1 text-base-content/70 hover:text-base-content"
                aria-label="Rename board"
              >
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <button
                type="button"
                id={"board-delete-#{board.id}"}
                phx-click="delete_board"
                phx-value-board_id={board.id}
                data-confirm="Delete this board and all its lists and cards?"
                class="rounded-md bg-base-300/70 p-1 text-base-content/70 hover:text-error"
                aria-label="Delete board"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </li>
        </ul>

        <form id="new-board-form" phx-submit="create_board" class="flex gap-2 max-w-sm">
          <input
            type="text"
            name="title"
            autocomplete="off"
            placeholder="New board title"
            class="input input-bordered w-full text-sm bg-base-100/40"
          />
          <button type="submit" class="btn btn-primary btn-sm">Create board</button>
        </form>
      </div>
    </Layouts.app>
    """
  end
end
