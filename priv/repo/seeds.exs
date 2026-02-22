# Script for populating the database. Run with:
#
#     mix run priv/repo/seeds.exs
#
# In production this runs automatically on every deploy via the
# `release_command` in fly.toml. All operations are idempotent (upsert).

alias SeventhWardEq.Accounts
alias SeventhWardEq.Accounts.User
alias SeventhWardEq.Repo

# ---------------------------------------------------------------------------
# Superadmin upsert
# ---------------------------------------------------------------------------
# Reads credentials from env vars. Raises a clear error on missing values so a
# misconfigured deploy fails loudly rather than silently skipping the seed.

email =
  System.get_env("SUPERADMIN_EMAIL") ||
    raise """
    SUPERADMIN_EMAIL environment variable is missing.
    Set it before running seeds:
        export SUPERADMIN_EMAIL=admin@example.com
    """

password =
  System.get_env("SUPERADMIN_PASSWORD") ||
    raise """
    SUPERADMIN_PASSWORD environment variable is missing.
    Set it before running seeds:
        export SUPERADMIN_PASSWORD=<strong-password>
    """

case Accounts.get_user_by_email(email) do
  nil ->
    %User{}
    |> User.email_changeset(%{email: email})
    |> User.password_changeset(%{password: password})
    |> User.admin_changeset(%{role: "superadmin", auxiliary: nil})
    |> User.confirm_changeset()
    |> Repo.insert!()

    IO.puts("Superadmin created: #{email}")

  existing ->
    existing
    |> User.admin_changeset(%{role: "superadmin", auxiliary: nil})
    |> Repo.update!()

    IO.puts("Superadmin confirmed: #{email}")
end
