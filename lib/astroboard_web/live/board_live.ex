defmodule AstroboardWeb.BoardLive do
  use AstroboardWeb, :live_view

  import AstroboardWeb.BoardLive.Components

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
      |> assign(:members, [])
      |> assign(:owner, nil)

    {:ok, stream_lists(socket, board.lists)}
  end

  @impl true
  def handle_params(%{"card_id" => card_id}, _uri, %{assigns: %{live_action: :card}} = socket) do
    card =
      Boards.get_board_card!(socket.assigns.current_scope, socket.assigns.board.id, card_id)

    {:noreply,
     socket
     |> assign(:selected_card, card)
     |> assign(:card_form, to_form(Boards.change_card(card)))}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :members}} = socket) do
    {:noreply, socket |> assign(selected_card: nil, card_form: nil) |> load_members()}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, selected_card: nil, card_form: nil)}
  end

  @impl true
  def handle_event("add_card", %{"list_id" => list_id, "title" => title}, socket) do
    index = list_index(socket.assigns.lists, list_id)
    list = index && Enum.at(socket.assigns.lists, index)

    case list && Boards.create_card(socket.assigns.current_scope, list, %{title: title}) do
      {:ok, card} ->
        {:noreply, stream_insert(socket, stream_name(index), card)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("add_list", %{"title" => title}, socket) do
    case Boards.create_list(socket.assigns.current_scope, socket.assigns.board, %{title: title}) do
      {:ok, list} ->
        index = length(socket.assigns.lists)

        {:noreply,
         socket
         |> update(:lists, &(&1 ++ [%{list | cards: []}]))
         |> stream(stream_name(index), [])}

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

    case list && Boards.update_list(socket.assigns.current_scope, list, %{title: title}) do
      {:ok, _updated} ->
        {:noreply, socket |> assign(:editing_list_id, nil) |> reload_board()}

      _ ->
        {:noreply, assign(socket, :editing_list_id, nil)}
    end
  end

  def handle_event("delete_list", %{"list_id" => list_id}, socket) do
    list = Enum.find(socket.assigns.lists, &(&1.id == to_int(list_id)))
    if list, do: Boards.delete_list(socket.assigns.current_scope, list)

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

    case Boards.update_card(socket.assigns.current_scope, card, params) do
      {:ok, updated} ->
        index = list_index(socket.assigns.lists, updated.list_id)

        {:noreply,
         socket
         |> stream_insert(stream_name(index), updated)
         |> push_patch(to: ~p"/boards/#{socket.assigns.board.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :card_form, to_form(changeset))}
    end
  end

  def handle_event("delete_card", _params, socket) do
    card = socket.assigns.selected_card
    {:ok, _} = Boards.delete_card(socket.assigns.current_scope, card)
    index = list_index(socket.assigns.lists, card.list_id)

    {:noreply,
     socket
     |> stream_delete(stream_name(index), card)
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

  def handle_event(event, _params, %{assigns: %{selected_card: nil}} = socket)
      when event in ~w(add_checklist_item toggle_checklist_item delete_checklist_item) do
    {:noreply, socket}
  end

  def handle_event("toggle_label", _params, %{assigns: %{selected_card: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_label", %{"color" => color}, socket) do
    Boards.toggle_label(socket.assigns.current_scope, socket.assigns.selected_card.id, color)
    {:noreply, reload_selected_card(socket)}
  end

  def handle_event("add_checklist_item", %{"content" => content}, socket) do
    case Boards.add_checklist_item(
           socket.assigns.current_scope,
           socket.assigns.selected_card.id,
           content
         ) do
      {:ok, _} -> {:noreply, reload_selected_card(socket)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("toggle_checklist_item", %{"item_id" => item_id}, socket) do
    Boards.toggle_checklist_item(socket.assigns.current_scope, to_int(item_id))
    {:noreply, reload_selected_card(socket)}
  end

  def handle_event("delete_checklist_item", %{"item_id" => item_id}, socket) do
    Boards.delete_checklist_item(socket.assigns.current_scope, to_int(item_id))
    {:noreply, reload_selected_card(socket)}
  end

  def handle_event("invite_member", %{"email" => email}, socket) do
    if owner?(socket) do
      case Boards.add_member(socket.assigns.current_scope, socket.assigns.board.id, email) do
        {:ok, _} ->
          {:noreply, socket |> put_flash(:info, "Member added.") |> load_members()}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "No user found with that email.")}

        {:error, :already_member} ->
          {:noreply, put_flash(socket, :error, "That user is already a member.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_member", %{"user_id" => user_id}, socket) do
    if owner?(socket) do
      Boards.remove_member(socket.assigns.current_scope, socket.assigns.board.id, to_int(user_id))
      {:noreply, load_members(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  # Ignore our own broadcasts — the acting event already updated locally.
  def handle_info({:cards_changed, from, _list_ids}, socket) when from == self() do
    {:noreply, socket}
  end

  def handle_info({:board_structure_changed, from}, socket) when from == self() do
    {:noreply, socket}
  end

  # A remote viewer: restream only the affected columns for card changes...
  def handle_info({:cards_changed, _from, list_ids}, socket) do
    {:noreply, restream_columns(socket, list_ids)}
  end

  # ...and reload fully for structural (list add/rename/remove) changes.
  def handle_info({:board_structure_changed, _from}, socket) do
    {:noreply, reload_board(socket)}
  end

  # Re-fetch the board and reset every column's card stream to the canonical order.
  defp reload_board(socket) do
    board = Boards.get_board!(socket.assigns.current_scope, socket.assigns.board.id)

    socket
    |> assign(:board, board)
    |> assign(:lists, board.lists)
    |> stream_lists(board.lists, reset: true)
  end

  # Stream each list's cards into a column-indexed stream. Naming by column
  # index (not list id) keeps the atom table bounded by the max number of
  # columns ever rendered, since atoms are never garbage-collected.
  defp stream_lists(socket, lists, opts \\ []) do
    lists
    |> Enum.with_index()
    |> Enum.reduce(socket, fn {list, index}, acc ->
      stream(acc, stream_name(index), list.cards, opts)
    end)
  end

  defp list_index(lists, list_id) do
    Enum.find_index(lists, &(to_string(&1.id) == to_string(list_id)))
  end

  defp owner?(socket) do
    socket.assigns.board.user_id == socket.assigns.current_scope.user.id
  end

  defp card_labels(%{card_labels: labels}) when is_list(labels), do: labels
  defp card_labels(_card), do: []

  defp label_bg("violet"), do: "bg-violet-500"
  defp label_bg("cyan"), do: "bg-cyan-400"
  defp label_bg("magenta"), do: "bg-pink-500"
  defp label_bg("amber"), do: "bg-amber-400"
  defp label_bg("green"), do: "bg-emerald-400"
  defp label_bg("coral"), do: "bg-rose-400"
  defp label_bg(_color), do: "bg-base-300"

  defp checklist_total(%{checklist_items: items}) when is_list(items), do: length(items)
  defp checklist_total(_card), do: 0

  defp checklist_done(%{checklist_items: items}) when is_list(items),
    do: Enum.count(items, & &1.done)

  defp checklist_done(_card), do: 0

  # Re-fetch the open card (with checklist items) and refresh its card-face tile.
  defp reload_selected_card(socket) do
    scope = socket.assigns.current_scope
    card = Boards.get_board_card!(scope, socket.assigns.board.id, socket.assigns.selected_card.id)
    index = list_index(socket.assigns.lists, card.list_id)

    socket
    |> assign(:selected_card, card)
    |> stream_insert(stream_name(index), card)
  end

  # Amber when the due date is today or past, muted otherwise.
  defp due_class(date) do
    if Date.compare(date, Date.utc_today()) != :gt,
      do: "text-warning",
      else: "text-base-content/50"
  end

  defp load_members(socket) do
    %{owner: owner, members: members} =
      Boards.list_members(socket.assigns.current_scope, socket.assigns.board.id)

    assign(socket, owner: owner, members: members)
  end

  # Re-fetch and reset only the given lists' card streams (targeted update for
  # remote viewers, instead of reloading the whole board).
  defp restream_columns(socket, list_ids) do
    Enum.reduce(list_ids, socket, fn list_id, acc ->
      case list_index(acc.assigns.lists, list_id) do
        nil ->
          acc

        index ->
          cards = Boards.list_cards(acc.assigns.current_scope, list_id)
          stream(acc, stream_name(index), cards, reset: true)
      end
    end)
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp stream_name(index), do: :"cards_#{index}"

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
          <span class="flex-1"></span>
          <.link patch={~p"/boards/#{@board.id}/members"} class="btn btn-sm" id="members-button">
            <.icon name="hero-user-group" class="size-4" /> Members
          </.link>
        </header>

        <div id="board-lists" class="flex gap-4 overflow-x-auto pb-4 items-start">
          <section
            :for={{list, index} <- Enum.with_index(@lists)}
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
                :for={{dom_id, card} <- @streams[stream_name(index)]}
                id={dom_id}
                patch={~p"/boards/#{@board.id}/cards/#{card.id}"}
                draggable="true"
                data-card-id={card.id}
                class="card-cosmic block rounded-xl px-3 py-2.5 text-sm cursor-grab active:cursor-grabbing"
              >
                <span :if={card_labels(card) != []} class="mb-1.5 flex gap-1">
                  <span
                    :for={label <- card_labels(card)}
                    class={["h-1.5 w-6 rounded-full", label_bg(label.color)]}
                  ></span>
                </span>
                {card.title}
                <span class="mt-1 flex items-center gap-3 font-mono text-xs text-base-content/50">
                  <span
                    :if={card.due_date}
                    class={["flex items-center gap-1", due_class(card.due_date)]}
                  >
                    <.icon name="hero-clock" class="size-3" /> {Calendar.strftime(
                      card.due_date,
                      "%b %d"
                    )}
                  </span>
                  <span :if={checklist_total(card) > 0} class="flex items-center gap-1">
                    <.icon name="hero-check-circle" class="size-3" />
                    {checklist_done(card)}/{checklist_total(card)}
                  </span>
                </span>
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

      <.card_modal
        :if={@selected_card}
        card={@selected_card}
        card_form={@card_form}
        board_id={@board.id}
        colors={Boards.label_colors()}
      />
      <.members_modal
        :if={@live_action == :members}
        board_id={@board.id}
        owner={@owner}
        members={@members}
        can_manage={@owner && @owner.id == @current_scope.user.id}
      />
    </Layouts.app>
    """
  end
end
