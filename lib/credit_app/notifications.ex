defmodule CreditApp.Notifications do
  @moduledoc """
  Outbound notifications' boundary.

  Provides a small, testable API for composing and delivering user-facing messages.
  Currently, implements email delivery via `CreditApp.Mailer` (Swoosh adapter), with
  support for file attachments. Callers pass plain data and receive `{:ok, term} | {:error, term}`
  without caring about the transport details.

  Responsibilities:
    * Build and send transactional emails
    * Attach files when needed
    * Keep a stable public API while allowing transport/config changes per environment

  Extensibility:
    * Add functions per notification (e.g., `send_welcome/1`, `send_invoice/2`)
    * Swap or configure adapters in `CreditApp.Mailer` without changing callers
    * Optional: move delivery to a background job (e.g., Oban) while keeping the same API

  ## Examples

      iex> CreditApp.Notifications.send_assessment("user@example.com", "/tmp/summary.pdf")
      {:ok, _}
  """
  alias Swoosh.{Email, Attachment}
  alias CreditApp.Mailer

  @spec send_assessment(String.t(), binary) :: {:ok, term} | {:error, term}
  def send_assessment(to_email, pdf_path) do
    attachment =
      Attachment.new(pdf_path,
        filename: "credit_assessment.pdf",
        content_type: "application/pdf"
      )

    Email.new()
    |> Email.to(to_email)
    |> Email.from({"Credit App", "no-reply@creditapp.local"})
    |> Email.subject("Congratulations, you're approved")
    |> Email.text_body("""
    Congratulations! You're approved for credit.

    Your credit assessment summary is attached as a PDF.

    If you didn’t request this, reply to this email.
    — Credit App
    """)
    |> Email.attachment(attachment)
    |> Mailer.deliver()
  end
end
