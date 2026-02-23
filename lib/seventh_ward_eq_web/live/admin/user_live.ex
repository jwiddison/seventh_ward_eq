defmodule SeventhWardEqWeb.Admin.UserLive do
  @moduledoc """
  Admin LiveView for user management (superadmin only).

  Handles two live actions:
  - `:index` — list all admin accounts with their auxiliary assignments
  - `:new`   — create a new admin account and send a welcome email

  Superadmin accounts are excluded from the list and cannot be deleted.
  """

  use SeventhWardEqWeb, :live_view

  alias SeventhWardEq.Accounts
  alias SeventhWardEq.Accounts.User
  alias SeventhWardEq.Auxiliary

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :admins, [])}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(_params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :auxiliary_options, auxiliary_options())

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <Layouts.admin_shell current_scope={@current_scope}>
        <div class="p-8">
          <%= if @live_action == :index do %>
            <.user_index admins={@admins} />
          <% else %>
            <.user_form form={@form} auxiliary_options={@auxiliary_options} />
          <% end %>
        </div>
      </Layouts.admin_shell>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_admin_creation(%User{}, user_params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.create_admin(user_params) do
      {:ok, new_user} ->
        Accounts.deliver_admin_welcome(
          new_user,
          &url(~p"/admin/log-in/#{&1}")
        )

        {:noreply,
         socket
         |> put_flash(:info, "Admin account created and welcome email sent.")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(String.to_integer(id))

    case Accounts.delete_admin(user, socket.assigns.current_scope.user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Admin account deleted.")
         |> assign(:admins, Accounts.list_admins())}

      {:error, reason} ->
        message =
          if reason == :cannot_delete_superadmin, do: "Cannot delete superadmin.", else: "Could not delete user."

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  defp apply_action(socket, :index) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:admins, Accounts.list_admins())
    |> assign(:form, nil)
  end

  defp apply_action(socket, :new) do
    changeset = Accounts.change_admin_creation(%User{})

    socket
    |> assign(:page_title, "New Admin")
    |> assign(:form, to_form(changeset))
  end

  @spec auxiliary_options() :: [{String.t(), String.t()}]
  defp auxiliary_options do
    Enum.map(Auxiliary.all(), fn aux -> {aux.name, aux.slug} end)
  end

  # ---------------------------------------------------------------------------
  # Sub-components
  # ---------------------------------------------------------------------------

  attr :admins, :list, required: true

  defp user_index(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold text-base-content">Users</h1>
      <.link navigate={~p"/admin/users/new"} class="btn btn-primary btn-sm">
        + New Admin
      </.link>
    </div>

    <%= if @admins == [] do %>
      <p class="text-base-content/50 italic">No admin accounts yet.</p>
    <% else %>
      <div class="overflow-x-auto rounded-xl border border-base-300">
        <table id="users-table" class="table w-full">
          <thead>
            <tr class="bg-base-200">
              <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">Email</th>
              <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">
                Auxiliary
              </th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            <%= for admin <- @admins do %>
              <tr id={"user-#{admin.id}"} class="border-t border-base-300 hover:bg-base-200/50 transition-colors">
                <td class="px-4 py-3 text-sm font-medium text-base-content">{admin.email}</td>
                <td class="px-4 py-3 text-sm text-base-content/60">
                  {auxiliary_name(admin.auxiliary)}
                </td>
                <td class="px-4 py-3">
                  <button
                    phx-click="delete"
                    phx-value-id={admin.id}
                    data-confirm={"Delete #{admin.email}?"}
                    class="text-xs text-error hover:underline"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  attr :form, :map, required: true
  attr :auxiliary_options, :list, required: true

  defp user_form(assigns) do
    ~H"""
    <div class="max-w-lg">
      <div class="flex items-center gap-3 mb-6">
        <.link navigate={~p"/admin/users"} class="text-base-content/40 hover:text-base-content">
          <.icon name="hero-arrow-left-micro" class="size-5" />
        </.link>
        <h1 class="text-2xl font-bold text-base-content">New Admin</h1>
      </div>

      <.form
        for={@form}
        id="user-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-5"
      >
        <.input field={@form[:email]} type="email" label="Email" required />

        <.input
          field={@form[:auxiliary]}
          type="select"
          label="Auxiliary"
          options={@auxiliary_options}
          prompt="Select an auxiliary…"
          required
        />

        <.input
          field={@form[:password]}
          type="password"
          label="Temporary Password"
          required
        />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm Password"
          required
        />

        <p class="text-xs text-base-content/50">
          The admin will receive a welcome email with a login link. They can change
          their password via Account Settings after logging in.
        </p>

        <div class="flex gap-3">
          <.button type="submit" phx-disable-with="Creating…" class="btn btn-primary">
            Create Admin
          </.button>
          <.link navigate={~p"/admin/users"} class="btn btn-ghost">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @spec auxiliary_name(String.t() | nil) :: String.t()
  defp auxiliary_name(nil), do: "—"

  defp auxiliary_name(slug) do
    case Auxiliary.get_by_slug(slug) do
      %{name: name} -> name
      nil -> slug
    end
  end
end
