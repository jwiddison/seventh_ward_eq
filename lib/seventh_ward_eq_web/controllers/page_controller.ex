defmodule SeventhWardEqWeb.PageController do
  use SeventhWardEqWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
