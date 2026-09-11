defmodule AstroboardWeb.UserLive.ForgotPasswordTest do
  use AstroboardWeb.ConnCase

  import Phoenix.LiveViewTest
  import Astroboard.AccountsFixtures

  alias Astroboard.Accounts.UserToken
  alias Astroboard.Repo

  describe "forgot password page" do
    test "renders the page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password")

      assert html =~ "Forgot your password?"
      assert html =~ "Send reset link"
    end
  end

  describe "send reset password instructions" do
    setup do
      %{user: user_fixture()}
    end

    test "sends a reset password token when user exists", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        form(lv, "#reset_password_form", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      assert Repo.get_by!(UserToken, user_id: user.id).context == "reset_password"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password")

      {:ok, _lv, html} =
        form(lv, "#reset_password_form", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
      assert Repo.all(UserToken) == []
    end
  end
end
