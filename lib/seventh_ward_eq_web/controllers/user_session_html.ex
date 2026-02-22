defmodule SeventhWardEqWeb.UserSessionHTML do
  use SeventhWardEqWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:seventh_ward_eq, SeventhWardEq.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
