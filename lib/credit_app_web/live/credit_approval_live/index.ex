defmodule CreditAppWeb.CreditApprovalLive.Index do
  use CreditAppWeb, :live_view

  alias CreditApp.Underwriting
  alias CreditApp.{PDF, Notifications}

  @order [:eligibility, :financials, :offer, :email]
  @labels %{eligibility: "Eligibility", financials: "Financials", offer: "Offer", email: "Email"}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(step: :eligibility)
     |> assign(order: @order, labels: @labels)
     |> assign(points: 0, credit: nil, income: 0, expenses: 0)
     |> assign(questions: Underwriting.questions(), answers: %{})
     |> assign(
       eligibility_form: eligibility_form(),
       financials_form: financials_form(),
       email_form: email_form()
     )}
  end

  # Eligibility -> Financials
  def handle_event("submit-eligibility", %{"eligibility" => params}, socket) do
    answers =
      for {k, _l, pts} <- socket.assigns.questions, into: %{} do
        v = Map.get(params, Atom.to_string(k), "no") == "yes"
        {k, {v, pts}}
      end

    points = answers |> Enum.into(%{}, fn {k, {v, _}} -> {k, v} end) |> Underwriting.score()

    socket = assign(socket, answers: answers, points: points)

    if Underwriting.approved?(points),
      do: {:noreply, assign(socket, step: :financials)},
      else: {:noreply, assign(socket, step: :not_eligible)}
  end

  # Financials -> Offer
  def handle_event(
        "submit-financials",
        %{"financials" => %{"income" => inc, "expenses" => exp}},
        socket
      ) do
    with {income, _} <- Float.parse(inc),
         {expenses, _} <- Float.parse(exp),
         true <- income >= 0 and expenses >= 0 do
      credit = Underwriting.offer_amount(income, expenses)

      {:noreply, assign(socket, step: :offer, income: income, expenses: expenses, credit: credit)}
    else
      _ -> {:noreply, put_flash(socket, :info, "Enter valid non-negative numbers.")}
    end
  end

  # Offer -> Email
  def handle_event("send-email", %{"email" => %{"address" => address}}, socket) do
    with {:ok, path} <- PDF.generate(socket.assigns),
         {:ok, _} <- Notifications.send_assessment(address, path) do
      {:noreply, assign(socket, step: :email)}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :info, "Failed: #{inspect(reason)}")}
    end
  end

  # Forms
  defp eligibility_form do
    to_form(
      %{
        "paying_job" => "no",
        "consistent_job_12m" => "no",
        "own_home" => "no",
        "own_car" => "no",
        "additional_income" => "no"
      },
      as: :eligibility
    )
  end

  defp financials_form do
    to_form(%{"income" => "", "expenses" => ""}, as: :financials)
  end

  defp email_form do
    to_form(%{"address" => ""}, as: :email)
  end
end
