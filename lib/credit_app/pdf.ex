defmodule CreditApp.PDF do
  @moduledoc """
  Generates the credit assessment PDF from plain assigns.

  ## Purpose
  Builds a static HTML summary for eligibility and financials, escapes any
  untrusted text with `Phoenix.HTML.html_escape/1` and `safe_to_string/1`,
  then renders a PDF via `PdfGenerator`.

  ## Input
    * `answers` — `%{atom => {boolean, points}}` as captured from the eligibility step
    * `points` — total eligibility score (non-negative integer)
    * `income` — monthly income (number)
    * `expenses` — monthly expenses (number)
    * `credit` — approved annual offer amount (number)

  ## Output
    * `{:ok, pdf_path}` on success (temporary file path)
    * `{:error, reason}` on failure

  ## Requirements
  `PdfGenerator` needs either `wkhtmltopdf` or chrome-headless available on PATH
  (or configured via `:pdf_generator`), and can also return an in-memory binary
  via `generate_binary/2` if desired.

  ## Example

      {:ok, path} =
        CreditApp.PDF.generate(%{
          answers: %{paying_job: {true, 4}, own_home: {false, 2}},
          points: 6,
          income: 4000.00,
          expenses: 2200.00,
          credit: 21600.00
        })

  """
  import Phoenix.HTML, only: [html_escape: 1, safe_to_string: 1]
  alias CreditApp.Underwriting

  @spec generate(%{
          answers: %{atom => {boolean, pos_integer}},
          points: non_neg_integer,
          income: number | nil,
          expenses: number | nil,
          credit: number | nil
        }) :: {:ok, binary} | {:error, term}
  def generate(%{
        answers: answers,
        points: points,
        income: income,
        expenses: expenses,
        credit: credit
      }) do
    html = build_html(answers, points, income, expenses, credit)
    PdfGenerator.generate(html, page_size: "A4", delete_temporary: true)
  end

  defp build_html(answers, points, income, expenses, credit) do
    rows =
      answers
      |> Enum.map(fn {key, {bool, pts}} ->
        label = Enum.find_value(Underwriting.questions(), fn {k, l, _} -> if k == key, do: l end)

        """
        <tr>
          <td>#{escape(label)}</td>
          <td>#{yn(bool)}</td>
          <td style="text-align:right;">#{pts}</td>
        </tr>
        """
      end)
      |> Enum.join()

    dateTime        = DateTime.utc_now() |> DateTime.truncate(:second)
    human_timestamp = Calendar.strftime(dateTime, "%B %-d, %Y %H:%M UTC")

    """
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        * { box-sizing: border-box; }
        body { font-family: Arial, sans-serif; color:#111; margin:28px; }
        h2 { margin: 0 0 4px; }
        h3 { margin: 18px 0 6px; }
        .muted { color:#666; font-size:12px; }
        table { width: 100%; border-collapse: collapse; margin-top: 8px; }
        th, td { border: 1px solid #ccc; padding: 8px; vertical-align: top; }
        th { text-align: left; background: #f5f5f5; }
        .right { text-align: right; }
        tfoot th, tfoot td { font-weight: bold; }
      </style>
    </head>
    <body>
      <h2>Credit Assessment Summary</h2>
      <p class="muted">Generated on #{human_timestamp}</p>

      <h3>Eligibility</h3>
      <table>
        <thead><tr><th>Question</th><th>Answer</th><th class="right">Points</th></tr></thead>
        <tbody>#{rows}</tbody>
        <tfoot><tr><th colspan="2">Total Points</th><td class="right">#{points}</td></tr></tfoot>
      </table>

      <h3>Financials</h3>
      <table>
        <tbody>
          <tr><td>Monthly Income (USD)</td><td class="right">#{money(income)}</td></tr>
          <tr><td>Monthly Expenses (USD)</td><td class="right">#{money(expenses)}</td></tr>
        </tbody>
        <tfoot><tr><th>Approved Credit (USD)</th><td class="right">#{money(credit)}</td></tr></tfoot>
      </table>
    </body>
    </html>
    """
  end

  defp yn(true), do: "Yes"
  defp yn(false), do: "No"

  defp money(nil), do: "-"
  defp money(v) when is_number(v), do: :io_lib.format("~.2f", [v]) |> IO.iodata_to_binary()

  # HTML escape for labels
  def escape(nil), do: ""
  def escape(term), do: term |> html_escape() |> safe_to_string()
end
