defmodule LivebookWeb.SidebarHelpers do
  use Phoenix.Component

  import LivebookWeb.LiveHelpers
  import LivebookWeb.UserHelpers

  alias Phoenix.LiveView.JS
  alias Livebook.Hub.Settings
  alias LivebookWeb.Router.Helpers, as: Routes

  @doc """
  Renders sidebar container.
  """
  def sidebar(assigns) do
    ~H"""
    <nav
      class="w-[18.75rem] min-w-[14rem] flex flex-col justify-between py-7 bg-gray-900"
      aria-label="sidebar"
      data-el-sidebar
    >
      <div class="flex flex-col">
        <div class="space-y-3">
          <div class="group flex items-center mb-5">
            <%= live_redirect to: Routes.home_path(@socket, :page), class: "flex items-center border-l-4 border-gray-900" do %>
              <img
                src="/images/logo.png"
                class="group mx-2"
                height="40"
                width="40"
                alt="logo livebook"
              />
              <span class="text-gray-300 text-2xl font-logo ml-[-1px] group-hover:text-white pt-1">
                Livebook
              </span>
            <% end %>
            <span class="text-gray-300 text-xs font-normal font-sans mx-2.5 pt-3 cursor-default">
              v<%= Application.spec(:livebook, :vsn) %>
            </span>
          </div>
          <.sidebar_link
            title="Home"
            icon="home-6-line"
            to={Routes.home_path(@socket, :page)}
            current={@current_page}
          />
          <.sidebar_link
            title="Explore"
            icon="compass-3-line"
            to={Routes.explore_path(@socket, :page)}
            current={@current_page}
          />
          <.sidebar_link
            title="Settings"
            icon="settings-3-line"
            to={Routes.settings_path(@socket, :page)}
            current={@current_page}
          />
        </div>
        <.hub_section socket={@socket} hubs={@saved_hubs} />
      </div>
      <div class="flex flex-col">
        <%= if Livebook.Config.shutdown_enabled?() do %>
          <button
            class="h-7 flex items-center text-gray-400 hover:text-white border-l-4 border-transparent hover:border-white"
            aria-label="shutdown"
            phx-click={
              with_confirm(
                JS.push("shutdown"),
                title: "Shut Down",
                description: "Are you sure you want to shut down Livebook now?",
                confirm_text: "Shut Down",
                confirm_icon: "shut-down-line"
              )
            }
          >
            <.remix_icon icon="shut-down-line" class="text-lg leading-6 w-[56px] flex justify-center" />
            <span class="text-sm font-medium">
              Shut Down
            </span>
          </button>
        <% end %>
        <button
          class="mt-8 flex items-center group border-l-4 border-transparent"
          aria_label="user profile"
          phx-click={show_current_user_modal()}
        >
          <div class="w-[56px] flex justify-center">
            <.user_avatar
              user={@current_user}
              class="w-8 h-8 group-hover:ring-white group-hover:ring-2"
              text_class="text-xs"
            />
          </div>
          <span class="text-sm text-gray-400 font-medium group-hover:text-white">
            <%= @current_user.name %>
          </span>
        </button>
      </div>
    </nav>
    """
  end

  defp sidebar_link(assigns) do
    ~H"""
    <%= live_redirect to: @to, class: "h-7 flex items-center hover:text-white #{sidebar_link_text_color(@to, @current)} border-l-4 #{sidebar_link_border_color(@to, @current)} hover:border-white" do %>
      <.remix_icon icon={@icon} class="text-lg leading-6 w-[56px] flex justify-center" />
      <span class="text-sm font-medium">
        <%= @title %>
      </span>
    <% end %>
    """
  end

  defp hub_section(assigns) do
    ~H"""
    <%= if Application.get_env(:livebook, :feature_flags)[:hub] do %>
      <div id="sidebar--hub" class="flex flex-col mt-12">
        <div class="space-y-1">
          <div class="grid grid-cols-1 md:grid-cols-2 relative leading-6 mb-2">
            <div class="flex flex-col">
              <small class="ml-5 font-medium text-white">HUBS</small>
            </div>
            <div class="flex flex-col">
              <%= live_redirect to: hub_path(@socket),
                              class: "flex absolute right-5 items-center justify-center
                                      text-gray-400 hover:text-white hover:border-white" do %>
                <.remix_icon icon="add-line" />
              <% end %>
            </div>
          </div>

          <%= for machine <- @hubs do %>
            <%= live_redirect to: hub_path(@socket, :edit, machine.id), class: "h-7 flex items-center cursor-pointer text-gray-400 hover:text-white" do %>
              <.remix_icon
                class="text-lg leading-6 w-[56px] flex justify-center"
                icon="checkbox-blank-circle-fill"
                style={"color: #{machine.color}"}
              />

              <span class="text-sm font-medium">
                <%= machine.name %>
              </span>
            <% end %>
          <% end %>

          <div class="h-7 flex items-center cursor-pointer text-gray-400 hover:text-white mt-2">
            <%= live_redirect to: hub_path(@socket), class: "h-7 flex items-center cursor-pointer text-gray-400 hover:text-white" do %>
              <.remix_icon class="text-lg leading-6 w-[56px] flex justify-center" icon="add-line" />

              <span class="text-sm font-medium">
                Add Hub
              </span>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp hub_path(socket, action \\ :page, id \\ nil) do
    if Application.get_env(:livebook, :feature_flags)[:hub] do
      opts = if id, do: [socket, action, id], else: [socket, action]
      apply(Routes, :hub_path, opts)
    end
  end

  defp sidebar_link_text_color(to, current) when to == current, do: "text-white"
  defp sidebar_link_text_color(_to, _current), do: "text-gray-400"

  defp sidebar_link_border_color(to, current) when to == current, do: "border-white"
  defp sidebar_link_border_color(_to, _current), do: "border-transparent"

  def sidebar_handlers(socket) do
    socket |> attach_shutdown_event() |> attach_hub_event()
  end

  defp attach_shutdown_event(socket) do
    if Livebook.Config.shutdown_enabled?() do
      attach_hook(socket, :shutdown, :handle_event, fn
        "shutdown", _params, socket ->
          System.stop()
          {:halt, put_flash(socket, :info, "Livebook is shutting down. You can close this page.")}

        _event, _params, socket ->
          {:cont, socket}
      end)
    else
      socket
    end
  end

  defp attach_hub_event(socket) do
    if Application.get_env(:livebook, :feature_flags)[:hub] do
      socket
      |> assign(saved_hubs: Settings.fetch_machines())
      |> attach_hook(:hub, :handle_info, fn
        :update_hub, socket ->
          {:cont, assign(socket, saved_hubs: Settings.fetch_machines())}

        _event, socket ->
          {:cont, socket}
      end)
    else
      assign(socket, saved_hubs: [])
    end
  end
end
