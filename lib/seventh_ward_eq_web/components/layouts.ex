defmodule SeventhWardEqWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SeventhWardEqWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the main app layout shell — flash notifications and inner content.

  Used by all LiveViews (public and admin). Each LiveView is responsible
  for rendering its own header/navigation within the inner block.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main>
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders the admin portal shell — sidebar navigation + content area.

  All admin LiveViews wrap their content in this component (inside `Layouts.app`).
  The sidebar shows the current admin's auxiliary (or "All Auxiliaries" for
  superadmin) and adapts navigation links based on role.

  ## Examples

      <Layouts.admin_shell current_scope={@current_scope}>
        <h1>Dashboard</h1>
      </Layouts.admin_shell>

  """
  attr :current_scope, :map, required: true
  attr :current_section, :atom, default: nil

  slot :inner_block, required: true

  def admin_shell(assigns) do
    ~H"""
    <div class="flex h-screen bg-base-100">
      <%!-- Sidebar --%>
      <aside
        id="admin-sidebar"
        class="w-56 shrink-0 bg-base-200 border-r border-base-300 flex flex-col"
      >
        <%!-- Brand / context --%>
        <div class="px-4 py-5 border-b border-base-300">
          <p class="text-xs font-semibold uppercase tracking-wider text-base-content/40 mb-0.5">
            Admin Portal
          </p>
          <p class="text-sm font-bold text-base-content truncate">
            {auxiliary_label(@current_scope)}
          </p>
        </div>

        <%!-- Navigation --%>
        <nav class="flex-1 p-3 space-y-0.5">
          <.admin_nav_link
            navigate={~p"/admin"}
            icon="hero-squares-2x2-micro"
            current_section={@current_section}
            nav_key={:dashboard}
          >
            Dashboard
          </.admin_nav_link>
          <.admin_nav_link
            navigate={~p"/admin/posts"}
            icon="hero-document-text-micro"
            current_section={@current_section}
            nav_key={:posts}
          >
            Posts
          </.admin_nav_link>
          <.admin_nav_link
            navigate={~p"/admin/events"}
            icon="hero-calendar-days-micro"
            current_section={@current_section}
            nav_key={:events}
          >
            Events
          </.admin_nav_link>
          <%= if @current_scope.user.role == "superadmin" do %>
            <div class="pt-2 pb-1">
              <p class="px-3 text-xs font-semibold uppercase tracking-wider text-base-content/30">
                Superadmin
              </p>
            </div>
            <.admin_nav_link
              navigate={~p"/admin/users"}
              icon="hero-users-micro"
              current_section={@current_section}
              nav_key={:users}
            >
              Users
            </.admin_nav_link>
          <% end %>
        </nav>

        <%!-- Footer: user email + logout --%>
        <div class="p-3 border-t border-base-300 space-y-1">
          <p class="px-3 text-xs text-base-content/50 truncate">{@current_scope.user.email}</p>
          <.link
            href={~p"/admin/log-out"}
            method="delete"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-base-content/60
                   hover:bg-base-300 hover:text-base-content transition-colors"
          >
            <.icon name="hero-arrow-left-start-on-rectangle-micro" class="size-4 shrink-0" /> Log out
          </.link>
        </div>
      </aside>

      <%!-- Main content --%>
      <div class="flex-1 min-w-0 overflow-auto">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # Internal helper — sidebar nav link with active-state highlighting.
  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :current_section, :atom, default: nil
  attr :nav_key, :atom, default: nil
  slot :inner_block, required: true

  defp admin_nav_link(assigns) do
    assigns = assign(assigns, :active, assigns.nav_key != nil and assigns.nav_key == assigns.current_section)

    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
        @active && "bg-base-300 text-base-content font-semibold",
        !@active && "text-base-content/70 hover:bg-base-300 hover:text-base-content"
      ]}
    >
      <.icon name={@icon} class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  # Returns a human-readable label for the admin's auxiliary context.
  @spec auxiliary_label(map()) :: String.t()
  defp auxiliary_label(%{user: %{role: "superadmin"}}), do: "All Auxiliaries"
  defp auxiliary_label(%{user: %{auxiliary: nil}}), do: "—"

  defp auxiliary_label(%{user: %{auxiliary: slug}}) do
    case SeventhWardEq.Auxiliary.get_by_slug(slug) do
      %{name: name} -> name
      nil -> slug
    end
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
