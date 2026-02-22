defmodule SeventhWardEq.Repo do
  use Ecto.Repo,
    otp_app: :seventh_ward_eq,
    adapter: Ecto.Adapters.Postgres
end
