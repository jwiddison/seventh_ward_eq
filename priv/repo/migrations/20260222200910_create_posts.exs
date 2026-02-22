defmodule SeventhWardEq.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string, null: false
      add :body, :text, null: false
      add :author_id, references(:users, on_delete: :nilify_all), null: true
      add :auxiliary, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:posts, [:auxiliary, :inserted_at])
  end
end
