defmodule AstroboardWeb.BoardLive.Components do
  @moduledoc """
  Function components for the board UI, extracted from `BoardLive` to keep its
  render function focused. Events (save_card, delete_card, close) are handled by
  the parent LiveView — these components only render markup.
  """
  use AstroboardWeb, :html

  @doc """
  The board members modal. The owner (when `can_manage`) can invite existing
  users by email and remove members; everyone with access sees the roster.
  Events are handled by the parent LiveView.
  """
  attr :board_id, :any, required: true
  attr :owner, :any, required: true, doc: "the owner user"
  attr :members, :list, required: true, doc: "member users"
  attr :can_manage, :boolean, default: false

  def members_modal(assigns) do
    ~H"""
    <div
      id="members-modal"
      class="fixed inset-0 z-30 flex items-start justify-center p-4 sm:p-8 overflow-y-auto"
    >
      <.link
        patch={~p"/boards/#{@board_id}"}
        class="fixed inset-0 bg-base-300/60 backdrop-blur-sm"
        aria-label="Close"
      >
        <span class="sr-only">Close</span>
      </.link>
      <div class="glass-panel relative w-full max-w-md rounded-2xl p-6 mt-8 space-y-5 shadow-2xl">
        <div class="flex items-start gap-3">
          <span class="cosmic-badge size-6 rounded-lg mt-1" />
          <div class="flex-1">
            <h2 class="font-semibold">Members</h2>
            <p class="text-xs text-base-content/50">Owner and collaborators</p>
          </div>
          <.link
            patch={~p"/boards/#{@board_id}"}
            class="text-base-content/50 hover:text-base-content"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </.link>
        </div>

        <form :if={@can_manage} id="invite-form" phx-submit="invite_member" class="flex gap-2">
          <input
            type="email"
            name="email"
            autocomplete="off"
            placeholder="Invite an existing user by email"
            class="input input-sm input-bordered w-full text-sm bg-base-100/40"
          />
          <button type="submit" class="btn btn-sm btn-primary">Invite</button>
        </form>

        <ul class="space-y-1">
          <li class="flex items-center gap-3 rounded-lg px-2 py-2">
            <span class="cosmic-badge size-7 rounded-full" />
            <div class="flex-1 min-w-0">
              <p class="text-sm truncate">{@owner.email}</p>
              <p class="text-xs text-base-content/50">Owner</p>
            </div>
          </li>
          <li
            :for={member <- @members}
            class="flex items-center gap-3 rounded-lg px-2 py-2 hover:bg-base-100/40"
          >
            <span class="size-7 rounded-full bg-base-300" />
            <div class="flex-1 min-w-0">
              <p class="text-sm truncate">{member.email}</p>
              <p class="text-xs text-base-content/50">Member</p>
            </div>
            <button
              :if={@can_manage}
              type="button"
              id={"member-remove-#{member.id}"}
              phx-click="remove_member"
              phx-value-user_id={member.id}
              data-confirm="Remove this member from the board?"
              class="text-base-content/50 hover:text-error"
              aria-label="Remove member"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  @doc """
  The card detail modal. Renders over the board; its form and actions target the
  parent LiveView. Guard the caller with `:if={@selected_card}`.
  """
  attr :card_form, :any, required: true, doc: "the to_form/1 changeset for the card"
  attr :board_id, :any, required: true, doc: "the board id, for close/cancel patches"
  attr :card, :any, required: true, doc: "the selected card, with checklist_items preloaded"
  attr :colors, :list, required: true, doc: "the label color palette"

  def card_modal(assigns) do
    ~H"""
    <div
      id="card-modal"
      class="fixed inset-0 z-30 flex items-start justify-center p-4 sm:p-8 overflow-y-auto"
    >
      <.link
        patch={~p"/boards/#{@board_id}"}
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
            patch={~p"/boards/#{@board_id}"}
            class="text-base-content/50 hover:text-base-content"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </.link>
        </div>

        <div class="space-y-2">
          <span class="mini-label" style="margin:0">Labels</span>
          <div class="flex gap-2">
            <button
              :for={color <- @colors}
              type="button"
              phx-click="toggle_label"
              phx-value-color={color}
              class={[
                "h-6 w-10 rounded transition",
                label_bg(color),
                (color in active_colors(@card) && "ring-2 ring-base-content/70") || "opacity-40"
              ]}
              aria-label={"Toggle #{color} label"}
            ></button>
          </div>
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
          <.input field={@card_form[:due_date]} type="date" label="Due date" />

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
              <.link patch={~p"/boards/#{@board_id}"} class="btn btn-sm btn-ghost">Cancel</.link>
              <button type="submit" class="btn btn-sm btn-primary">Save</button>
            </div>
          </div>
        </.form>

        <div class="space-y-3 border-t border-base-300/60 pt-4">
          <div class="flex items-center justify-between">
            <span class="mini-label" style="margin:0">Checklist</span>
            <span class="font-mono text-xs text-base-content/50">
              {checklist_done(@card)}/{checklist_total(@card)}
            </span>
          </div>

          <div class="h-1.5 rounded-full bg-base-300/60 overflow-hidden">
            <div
              class="h-full rounded-full bg-gradient-to-r from-violet-500 to-cyan-400"
              style={"width: #{checklist_pct(@card)}%"}
            >
            </div>
          </div>

          <div id="checklist-items" class="space-y-1">
            <div
              :for={item <- @card.checklist_items}
              id={"checklist-item-#{item.id}"}
              class="flex items-center gap-2 group"
            >
              <button
                type="button"
                phx-click="toggle_checklist_item"
                phx-value-item_id={item.id}
                class={[
                  "size-4 rounded border flex items-center justify-center shrink-0",
                  item.done && "bg-gradient-to-br from-violet-500 to-cyan-400 border-transparent",
                  !item.done && "border-base-300"
                ]}
                aria-label="Toggle item"
              >
                <.icon :if={item.done} name="hero-check" class="size-3 text-base-100" />
              </button>
              <span class={["flex-1 text-sm", item.done && "line-through text-base-content/40"]}>
                {item.content}
              </span>
              <button
                type="button"
                phx-click="delete_checklist_item"
                phx-value-item_id={item.id}
                class="text-base-content/40 hover:text-error opacity-0 group-hover:opacity-100"
                aria-label="Delete item"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
          </div>

          <form id="checklist-form" phx-submit="add_checklist_item" class="flex gap-2">
            <input
              type="text"
              name="content"
              autocomplete="off"
              placeholder="Add an item"
              class="input input-xs input-bordered w-full text-sm bg-base-100/40"
            />
            <button type="submit" class="btn btn-xs">Add</button>
          </form>
        </div>

        <div class="space-y-3 border-t border-base-300/60 pt-4">
          <span class="mini-label" style="margin:0">Activity</span>

          <form id="comment-form" phx-submit="add_comment" class="flex gap-2">
            <input
              type="text"
              name="body"
              autocomplete="off"
              placeholder="Write a comment…"
              class="input input-sm input-bordered w-full text-sm bg-base-100/40"
            />
            <button type="submit" class="btn btn-sm">Post</button>
          </form>

          <div id="comments" class="space-y-3">
            <div :for={comment <- @card.comments} class="flex gap-2 text-sm">
              <span class="size-6 rounded-full bg-base-300 shrink-0 mt-0.5" />
              <div class="min-w-0">
                <p class="text-xs text-base-content/50">
                  {comment.user.email} · {Calendar.strftime(comment.inserted_at, "%b %d, %H:%M")}
                </p>
                <p class="break-words">{comment.body}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp checklist_total(%{checklist_items: items}) when is_list(items), do: length(items)
  defp checklist_total(_card), do: 0

  defp checklist_done(%{checklist_items: items}) when is_list(items),
    do: Enum.count(items, & &1.done)

  defp checklist_done(_card), do: 0

  defp checklist_pct(card) do
    total = checklist_total(card)
    if total == 0, do: 0, else: round(checklist_done(card) / total * 100)
  end

  defp active_colors(%{card_labels: labels}) when is_list(labels),
    do: Enum.map(labels, & &1.color)

  defp active_colors(_card), do: []

  defp label_bg("violet"), do: "bg-violet-500"
  defp label_bg("cyan"), do: "bg-cyan-400"
  defp label_bg("magenta"), do: "bg-pink-500"
  defp label_bg("amber"), do: "bg-amber-400"
  defp label_bg("green"), do: "bg-emerald-400"
  defp label_bg("coral"), do: "bg-rose-400"
  defp label_bg(_color), do: "bg-base-300"
end
