defmodule AstroboardWeb.BoardLive.Components do
  @moduledoc """
  Function components for the board UI, extracted from `BoardLive` to keep its
  render function focused. Events (save_card, delete_card, close) are handled by
  the parent LiveView — these components only render markup.
  """
  use AstroboardWeb, :html

  @doc """
  The card detail modal. Renders over the board; its form and actions target the
  parent LiveView. Guard the caller with `:if={@selected_card}`.
  """
  attr :card_form, :any, required: true, doc: "the to_form/1 changeset for the card"
  attr :board_id, :any, required: true, doc: "the board id, for close/cancel patches"

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
              <.link patch={~p"/boards/#{@board_id}"} class="btn btn-sm btn-ghost">Cancel</.link>
              <button type="submit" class="btn btn-sm btn-primary">Save</button>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
