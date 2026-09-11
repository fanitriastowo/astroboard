defmodule AstroboardWeb.UserLive.ResetPassword do
  use AstroboardWeb, :live_view

  alias Astroboard.Accounts
  alias AstroboardWeb.UserAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm mt-6 glass-panel rounded-2xl p-6 space-y-4">
        <div class="flex items-center justify-center gap-2">
          <span class="cosmic-badge size-7 rounded-lg"></span>
          <span class="text-lg font-bold tracking-tight">Astroboard</span>
        </div>
        <div class="text-center">
          <.header>
            Reset password
            <:subtitle>Choose a new password for your account.</:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="reset_password_form"
          phx-change="validate"
          phx-submit="reset_password"
        >
          <.input
            field={@form[:password]}
            type="password"
            label="New password"
            autocomplete="new-password"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            autocomplete="new-password"
            spellcheck="false"
            required
          />
          <.button class="btn btn-primary w-full" phx-disable-with="Resetting...">
            Reset password
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      form = user |> Accounts.change_user_password(%{}, hash_password: false) |> to_form()
      {:ok, assign(socket, user: user, token: token, form: form)}
    else
      {:ok, invalid_link(socket)}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      socket.assigns.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("reset_password", %{"user" => user_params}, socket) do
    # Re-check the token: another tab may have used it, or it expired while the page was open.
    with %Accounts.User{} = user <-
           Accounts.get_user_by_reset_password_token(socket.assigns.token),
         {:ok, {_user, expired_tokens}} <- Accounts.reset_user_password(user, user_params) do
      UserAuth.disconnect_sessions(expired_tokens)

      {:noreply,
       socket
       |> put_flash(:info, "Password reset successfully.")
       |> push_navigate(to: ~p"/users/log-in")}
    else
      nil ->
        {:noreply, invalid_link(socket)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  defp invalid_link(socket) do
    socket
    |> put_flash(:error, "Reset password link is invalid or it has expired.")
    |> push_navigate(to: ~p"/users/log-in")
  end
end
