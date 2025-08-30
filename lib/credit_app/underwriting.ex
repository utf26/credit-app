defmodule CreditApp.Underwriting do
  @moduledoc """
  Underwriting rules and scoring.

  This context exposes pure, deterministic functions that:
    * define the eligibility questions and their weights (`questions/0`)
    * compute a total score from boolean answers (`score/1`)
    * decide eligibility against a policy threshold (`approved?/1`)
    * compute an offer amount from monthly income and expenses (`offer_amount/2`)

  Design notes
    * Business-centric naming and a single public boundary keep the domain clear.
    * No I/O or persistence; callers supply data and consume results.
    * The approval threshold is policy; adjust here or externalize to config if needed.

  Example

      iex> answers = %{paying_job: true, own_home: false}
      iex> points  = CreditApp.Underwriting.score(answers)
      iex> eligible = CreditApp.Underwriting.approved?(points)
      iex> offer    = CreditApp.Underwriting.offer_amount(4_000, 2_500)

  """
  @threshold 6

  @questions [
    {:paying_job, "Do you have a paying job?", 4},
    {:consistent_job_12m, "Have you been employed continuously in the past 12 months?", 2},
    {:own_home, "Do you own a home?", 2},
    {:own_car, "Do you own a car?", 1},
    {:additional_income, "Do you have any additional sources of income?", 2}
  ]

  @type answer_map :: %{optional(atom) => boolean}

  @spec questions() :: [{atom, String.t(), pos_integer}]
  def questions, do: @questions

  @spec score(answer_map) :: non_neg_integer
  def score(answers) do
    Enum.reduce(@questions, 0, fn {k, _label, pts}, acc ->
      if Map.get(answers, k, false), do: acc + pts, else: acc
    end)
  end

  @spec approved?(non_neg_integer) :: boolean
  def approved?(points), do: points > @threshold

  @spec offer_amount(number, number) :: float
  def offer_amount(income, expenses) do
    credit = (income - expenses) * 12
    if credit < 0, do: 0.0, else: credit * 1.0
  end
end
