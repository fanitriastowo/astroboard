defmodule AstroboardWeb.UserLive.ForgotPassword do
  use AstroboardWeb, :live_view

  alias Astroboard.Accounts

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
            Forgot your password?
            <:subtitle>We'll send a password reset link to your inbox.</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="reset_password_form" phx-submit="send_email">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full" phx-disable-with="Sending...">
            Send reset link
          </.button>
        </.form>

        <p class="text-center text-sm">
          <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
            Back to log in
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  @impl true
  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
