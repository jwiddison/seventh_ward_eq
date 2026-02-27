defmodule SeventhWardEqWeb.Admin.EventLive do
  @moduledoc """
  Admin LiveView for managing calendar events.

  Handles three live actions on the same LiveView module:
  - `:index` — list all events for the admin's auxiliary
  - `:new`   — create a new event
  - `:edit`  — update an existing event

  Superadmin sees all events with auxiliary labels.
  """

  use SeventhWardEqWeb, :live_view

  alias SeventhWardEq.Events
  alias SeventhWardEq.Events.Event

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:events, []) |> assign(:current_section, :events)}
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <Layouts.admin_shell current_scope={@current_scope} current_section={@current_section}>
        <div class="p-8">
          <%= if @live_action == :index do %>
            <.event_index events={@events} current_scope={@current_scope} />
          <% else %>
            <.event_form form={@form} live_action={@live_action} />
          <% end %>
        </div>
      </Layouts.admin_shell>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset = Events.change_event(form_event(socket), event_params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"event" => event_params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.live_action do
        :new -> Events.create_event(scope, event_params)
        :edit -> Events.update_event(socket.assigns.event, scope, event_params)
      end

    case result do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, flash_message(socket.assigns.live_action))
         |> push_navigate(to: ~p"/admin/events")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(String.to_integer(id))

    case Events.delete_event(event, socket.assigns.current_scope) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event deleted.")
         |> assign(:events, load_events(socket.assigns.current_scope))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete event.")}
    end
  end

  ################################################################################
  # PRIVATE
  ################################################################################

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Events")
    |> assign(:events, load_events(socket.assigns.current_scope))
    |> assign(:form, nil)
    |> assign(:event, nil)
  end

  defp apply_action(socket, :new, _params) do
    event = %Event{}
    changeset = Events.change_event(event)

    socket
    |> assign(:page_title, "New Event")
    |> assign(:event, event)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(String.to_integer(id))
    changeset = Events.change_event(event)

    socket
    |> assign(:page_title, "Edit Event")
    |> assign(:event, event)
    |> assign(:form, to_form(changeset))
  end

  @spec load_events(map()) :: [Event.t()]
  defp load_events(%{user: %{role: "superadmin"}}), do: Events.list_all_events()
  defp load_events(%{user: %{auxiliary: aux}}), do: Events.list_events(aux)

  @spec form_event(Phoenix.LiveView.Socket.t()) :: Event.t() | Ecto.Changeset.t()
  defp form_event(%{assigns: %{event: event}}), do: event

  @spec flash_message(atom()) :: String.t()
  defp flash_message(:new), do: "Event created."
  defp flash_message(:edit), do: "Event updated."

  # ---------------------------------------------------------------------------
  # Sub-components
  # ---------------------------------------------------------------------------

  attr :events, :list, required: true
  attr :current_scope, :map, required: true

  defp event_index(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold text-base-content">Events</h1>
      <%= if @current_scope.user.auxiliary do %>
        <.link navigate={~p"/admin/events/new"} class="btn btn-primary btn-sm">
          + New Event
        </.link>
      <% end %>
    </div>

    <%= if @events == [] do %>
      <p class="text-base-content/50 italic">No events yet.</p>
    <% else %>
      <div class="overflow-x-auto rounded-xl border border-base-300">
        <table id="events-table" class="table w-full">
          <thead>
            <tr class="bg-base-200">
              <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">Title</th>
              <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">Date</th>
              <%= if @current_scope.user.role == "superadmin" do %>
                <th class="text-left text-xs font-semibold uppercase tracking-wider text-base-content/50 px-4 py-3">
                  Auxiliary
                </th>
              <% end %>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody>
            <%= for event <- @events do %>
              <tr id={"event-#{event.id}"} class="border-t border-base-300 hover:bg-base-200/50 transition-colors">
                <td class="px-4 py-3 text-sm font-medium text-base-content">{event.title}</td>
                <td class="px-4 py-3 text-sm text-base-content/60">{format_date_range(event)}</td>
                <%= if @current_scope.user.role == "superadmin" do %>
                  <td class="px-4 py-3 text-sm text-base-content/60">{event.auxiliary}</td>
                <% end %>
                <td class="px-4 py-3">
                  <div class="flex items-center gap-2 justify-end">
                    <.link
                      navigate={~p"/admin/events/#{event.id}/edit"}
                      class="text-xs text-primary hover:underline"
                    >
                      Edit
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={event.id}
                      data-confirm="Delete this event?"
                      class="text-xs text-error hover:underline"
                    >
                      Delete
                    </button>
                  </div>
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
  attr :live_action, :atom, required: true

  defp event_form(assigns) do
    ~H"""
    <div class="max-w-2xl">
      <div class="flex items-center gap-3 mb-6">
        <.link navigate={~p"/admin/events"} class="text-base-content/40 hover:text-base-content">
          <.icon name="hero-arrow-left-micro" class="size-5" />
        </.link>
        <h1 class="text-2xl font-bold text-base-content">
          {if @live_action == :new, do: "New Event", else: "Edit Event"}
        </h1>
      </div>

      <.form
        for={@form}
        id="event-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-5"
      >
        <.input field={@form[:title]} type="text" label="Title" required />
        <.input field={@form[:description]} type="textarea" label="Description (optional)" rows="4" />
        <.input field={@form[:location]} type="text" label="Location (optional)" />

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input field={@form[:starts_on]} type="date" label="Start Date" required />
          <.input field={@form[:ends_on]} type="date" label="End Date (optional)" />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input field={@form[:start_time]} type="time" label="Start Time (optional)" />
          <.input field={@form[:end_time]} type="time" label="End Time (optional)" />
        </div>

        <div class="flex gap-3">
          <.button type="submit" phx-disable-with="Saving…" class="btn btn-primary">
            {if @live_action == :new, do: "Create Event", else: "Save Changes"}
          </.button>
          <.link navigate={~p"/admin/events"} class="btn btn-ghost">Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @spec format_date_range(Event.t()) :: String.t()
  defp format_date_range(event) do
    start_str = Calendar.strftime(event.starts_on, "%b %-d, %Y")

    if event.ends_on && event.ends_on != event.starts_on do
      end_str = Calendar.strftime(event.ends_on, "%b %-d, %Y")
      "#{start_str} – #{end_str}"
    else
      start_str
    end
  end
end
