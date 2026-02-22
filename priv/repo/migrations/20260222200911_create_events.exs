defmodule SeventhWardEq.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :title, :string, null: false
      add :description, :text
      add :location, :string
      add :starts_on, :date, null: false
      add :ends_on, :date
      add :start_time, :time
      add :end_time, :time
      add :author_id, references(:users, on_delete: :nilify_all), null: true
      add :auxiliary, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:events, [:auxiliary, :starts_on])
  end
end
