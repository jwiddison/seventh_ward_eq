defmodule SeventhWardEq.Repo.Migrations.AddRoleAndAuxiliaryToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "admin"
      add :auxiliary, :string, null: true
    end
  end
end
