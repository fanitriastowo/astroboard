defmodule AstroboardWeb.BoardLive do
  use AstroboardWeb, :live_view

  alias Astroboard.Boards

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    board = Boards.get_board!(socket.assigns.current_scope, id)

    if connected?(socket), do: Boards.subscribe(board.id)

    socket =
      socket
      |> assign(:page_title, board.title)
      |> assign(:board, board)
      |> assign(:lists, board.lists)
      |> assign(:selected_card, nil)
      |> assign(:card_form, nil)
      |> assign(:editing_list_id, nil)

    socket =
      Enum.reduce(board.lists, socket, fn list, acc ->
        stream(acc, stream_name(list.id), list.cards)
      end)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"card_id" => card_id}, _uri, %{assigns: %{live_action: :card}} = socket) do
    card = Boards.get_card!(socket.assigns.current_scope, card_id)

    {:noreply,
     socket
     |> assign(:selected_card, card)
     |> assign(:card_form, to_form(Boards.change_card(card)))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, selected_card: nil, card_form: nil)}
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

  def handle_event("edit_list", %{"list_id" => list_id}, socket) do
    {:noreply, assign(socket, :editing_list_id, to_int(list_id))}
  end

  def handle_event("cancel_edit_list", _params, socket) do
    {:noreply, assign(socket, :editing_list_id, nil)}
  end

  def handle_event("rename_list", %{"list_id" => list_id, "title" => title}, socket) do
    list = Enum.find(socket.assigns.lists, &(&1.id == to_int(list_id)))

    case list && Boards.update_list(list, %{title: title}) do
      {:ok, _updated} ->
        {:noreply, socket |> assign(:editing_list_id, nil) |> reload_board()}

      _ ->
        {:noreply, assign(socket, :editing_list_id, nil)}
    end
  end

  def handle_event("delete_list", %{"list_id" => list_id}, socket) do
    list = Enum.find(socket.assigns.lists, &(&1.id == to_int(list_id)))
    if list, do: Boards.delete_list(list)

    {:noreply, reload_board(socket)}
  end

  def handle_event("save_card", _params, %{assigns: %{selected_card: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("delete_card", _params, %{assigns: %{selected_card: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("save_card", %{"card" => params}, socket) do
    card = socket.assigns.selected_card

    case Boards.update_card(card, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> stream_insert(stream_name(updated.list_id), updated)
         |> push_patch(to: ~p"/boards/#{socket.assigns.board.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :card_form, to_form(changeset))}
    end
  end

  def handle_event("delete_card", _params, socket) do
    card = socket.assigns.selected_card
    {:ok, _} = Boards.delete_card(card)

    {:noreply,
     socket
     |> stream_delete(stream_name(card.list_id), card)
     |> push_patch(to: ~p"/boards/#{socket.assigns.board.id}")}
  end

  def handle_event(
        "move_card",
        %{"card_id" => card_id, "list_id" => list_id, "position" => pos},
        socket
      ) do
    with card_id when is_integer(card_id) <- to_int(card_id),
         list_id when is_integer(list_id) <- to_int(list_id),
         position when is_integer(position) <- to_int(pos),
         {:ok, _card} <-
           Boards.move_card(socket.assigns.current_scope, card_id, list_id, position) do
      {:noreply, reload_board(socket)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  # Ignore our own broadcast — the acting event already updated locally.
  def handle_info({:board_updated, from}, socket) when from != self() do
    {:noreply, reload_board(socket)}
  end

  def handle_info({:board_updated, _from}, socket) do
    {:noreply, socket}
  end

  # Re-fetch the board and reset every list's card stream to the canonical order.
  defp reload_board(socket) do
    board = Boards.get_board!(socket.assigns.current_scope, socket.assigns.board.id)

    socket
    |> assign(:board, board)
    |> assign(:lists, board.lists)
    |> then(fn s ->
      Enum.reduce(board.lists, s, fn list, acc ->
        stream(acc, stream_name(list.id), list.cards, reset: true)
      end)
    end)
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> nil
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
            <div class="flex items-center justify-between px-1 gap-2 group">
              <%= if @editing_list_id == list.id do %>
                <form
                  id={"rename-list-#{list.id}"}
                  phx-submit="rename_list"
                  phx-value-list_id={list.id}
                  class="flex-1"
                >
                  <input
                    type="text"
                    name="title"
                    value={list.title}
                    autocomplete="off"
                    phx-mounted={JS.focus()}
                    phx-blur="cancel_edit_list"
                    class="input input-xs input-bordered w-full text-sm bg-base-100/40"
                  />
                </form>
              <% else %>
                <h2 class="text-sm font-semibold flex-1 truncate">{list.title}</h2>
                <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    type="button"
                    id={"list-edit-#{list.id}"}
                    phx-click="edit_list"
                    phx-value-list_id={list.id}
                    class="text-base-content/50 hover:text-base-content"
                    aria-label="Rename list"
                  >
                    <.icon name="hero-pencil-square" class="size-4" />
                  </button>
                  <button
                    type="button"
                    id={"list-delete-#{list.id}"}
                    phx-click="delete_list"
                    phx-value-list_id={list.id}
                    data-confirm="Delete this list and all its cards?"
                    class="text-base-content/50 hover:text-error"
                    aria-label="Delete list"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              <% end %>
            </div>

            <div
              id={"cards-#{list.id}"}
              phx-hook="Drag"
              phx-update="stream"
              data-list-id={list.id}
              class="space-y-2 min-h-8"
            >
              <.link
                :for={{dom_id, card} <- @streams[stream_name(list.id)]}
                id={dom_id}
                patch={~p"/boards/#{@board.id}/cards/#{card.id}"}
                draggable="true"
                data-card-id={card.id}
                class="card-cosmic block rounded-xl px-3 py-2.5 text-sm cursor-grab active:cursor-grabbing"
              >
                {card.title}
              </.link>
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

      <div
        :if={@selected_card}
        id="card-modal"
        class="fixed inset-0 z-30 flex items-start justify-center p-4 sm:p-8 overflow-y-auto"
      >
        <.link
          patch={~p"/boards/#{@board.id}"}
          class="fixed inset-0 bg-base-300/60 backdrop-blur-sm"
          aria-label="Close"
        >
          <span class="sr-only">Close</span>
        </.link>
        <div class="glass-panel relative w-full max-w-xl rounded-2xl p-6 mt-8 space-y-5 shadow-2xl">
          <div class="flex items-start gap-3">
            <span class="cosmic-badge size-6 rounded-lg mt-1" />
            <div class="flex-1">
              <p class="text-xs text-base-content/50">Card</p>
            </div>
            <.link
              patch={~p"/boards/#{@board.id}"}
              class="text-base-content/50 hover:text-base-content"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </.link>
          </div>

          <.form for={@card_form} id="card-form" phx-submit="save_card" class="space-y-4">
            <.input field={@card_form[:title]} type="text" label="Title" required />
            <.input
              field={@card_form[:description]}
              type="textarea"
              label="Description"
              rows="5"
              placeholder="Add a more detailed description…"
            />

            <div class="flex items-center justify-between pt-2">
              <button
                type="button"
                id="card-delete"
                phx-click="delete_card"
                data-confirm="Delete this card?"
                class="btn btn-sm btn-ghost text-error"
              >
                <.icon name="hero-trash" class="size-4" /> Delete
              </button>
              <div class="flex gap-2">
                <.link patch={~p"/boards/#{@board.id}"} class="btn btn-sm btn-ghost">Cancel</.link>
                <button type="submit" class="btn btn-sm btn-primary">Save</button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
