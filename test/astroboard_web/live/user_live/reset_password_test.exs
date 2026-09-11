defmodule AstroboardWeb.UserLive.ResetPasswordTest do
  use AstroboardWeb.ConnCase

  import Phoenix.LiveViewTest
  import Astroboard.AccountsFixtures

  alias Astroboard.Accounts

  @new_password "new valid password"

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)

    %{user: user, token: token}
  end

  describe "reset password page" do
    test "renders the page with a valid token", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset-password/#{token}")

      assert html =~ "Reset password"
    end

    test "redirects to login with an invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/reset-password/invalid")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Reset password link is invalid or it has expired"
    end
  end

  describe "reset password" do
    test "renders errors on change", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      result =
        lv
        |> element("#reset_password_form")
        |> render_change(user: %{password: "too short", password_confirmation: "does not match"})

      assert result =~ "should be at least 12 character"
      assert result =~ "does not match password"
    end

    test "resets the password and expires the link", %{conn: conn, user: user, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      {:ok, _lv, html} =
        lv
        |> form("#reset_password_form",
          user: %{password: @new_password, password_confirmation: @new_password}
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Password reset successfully."
      assert Accounts.get_user_by_email_and_password(user.email, @new_password)
      refute Accounts.get_user_by_reset_password_token(token)
    end

    test "does not reset the password with invalid data", %{conn: conn, user: user, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset-password/#{token}")

      result =
        lv
        |> form("#reset_password_form",
          user: %{password: "too short", password_confirmation: "does not match"}
        )
        |> render_submit()

      assert result =~ "should be at least 12 character"
      assert result =~ "does not match password"
      refute Accounts.get_user_by_email_and_password(user.email, "too short")
    end

    test "rejects a second submit after the link was used in another tab", %{
      conn: conn,
      token: token
    } do
      {:ok, first_lv, _html} = live(conn, ~p"/users/reset-password/#{token}")
      {:ok, second_lv, _html} = live(conn, ~p"/users/reset-password/#{token}")
      params = %{password: @new_password, password_confirmation: @new_password}

      {:ok, _lv, _html} =
        first_lv
        |> form("#reset_password_form", user: params)
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        second_lv
        |> form("#reset_password_form", user: params)
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Reset password link is invalid or it has expired"
    end
  end
end
