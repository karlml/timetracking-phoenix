defmodule TimetrackingPhoenixWeb.ReportController do
  use TimetrackingPhoenixWeb, :controller

  alias TimetrackingPhoenix.{Projects, TimeEntries}

  # Currency symbols mapping
  @currency_symbols %{
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "JPY" => "¥",
    "CAD" => "C$",
    "AUD" => "A$",
    "CHF" => "CHF ",
    "CNY" => "¥",
    "INR" => "₹",
    "BRL" => "R$",
    "MXN" => "MX$",
    "ZAR" => "R",
    "SEK" => "kr ",
    "NOK" => "kr ",
    "DKK" => "kr ",
    "PLN" => "zł ",
    "NZD" => "NZ$",
    "SGD" => "S$",
    "HKD" => "HK$",
    "KRW" => "₩"
  }

  def export(conn, %{"project_id" => project_id} = params) do
    project = Projects.get_project!(project_id)
    project_members = Projects.list_project_members(project_id)
    
    # Parse date range from params
    {from_date, to_date} = parse_date_range(params)
    
    time_entries = if from_date && to_date do
      TimeEntries.list_project_time_entries_in_range(project, from_date, to_date)
    else
      TimeEntries.list_project_time_entries(project)
    end

    # Get project currency (default to USD if not set)
    project_currency = project.currency || "USD"
    currency_symbol = Map.get(@currency_symbols, project_currency, project_currency <> " ")

    # Build a map of user_id -> {rate, currency} from project members
    # Rate is set per-project for each developer
    member_rates = Map.new(project_members, fn member ->
      rate = member.hourly_rate || project.hourly_rate
      currency = member.currency || project_currency
      {member.user_id, {rate, currency}}
    end)

    # Calculate totals with per-developer rates
    {total_hours, total_amount} = Enum.reduce(time_entries, {Decimal.new(0), Decimal.new(0)}, fn entry, {hours_acc, amount_acc} ->
      {rate, _currency} = get_entry_rate(entry, member_rates, project)
      entry_amount = if rate, do: Decimal.mult(entry.hours, rate), else: Decimal.new(0)
      {Decimal.add(hours_acc, entry.hours), Decimal.add(amount_acc, entry_amount)}
    end)

    # Build CSV content
    csv_rows = time_entries
    |> Enum.map(fn entry ->
      user_name = if entry.user, do: "#{entry.user.first_name} #{entry.user.last_name}", else: "Unknown"
      {rate, entry_currency} = get_entry_rate(entry, member_rates, project)
      entry_symbol = Map.get(@currency_symbols, entry_currency, entry_currency <> " ")
      
      entry_amount = if rate do
        "#{entry_symbol}#{Decimal.round(Decimal.mult(entry.hours, rate), 2)}"
      else
        ""
      end
      
      [
        Date.to_string(entry.date),
        user_name,
        Decimal.to_string(Decimal.round(entry.hours, 2)),
        entry_amount,
        entry.description || ""
      ]
    end)
    
    # Add summary rows
    summary_rows = [
      [],
      ["SUMMARY"],
      ["Project:", project.name],
      ["Client:", project.client_name || "N/A"],
      ["Currency:", project_currency],
      ["Date Range:", format_date_range(from_date, to_date)],
      ["Total Hours:", Decimal.to_string(Decimal.round(total_hours, 2))],
      ["Hourly Rate:", if(project.hourly_rate, do: "#{currency_symbol}#{project.hourly_rate}", else: "N/A")],
      ["Total Amount:", "#{currency_symbol}#{Decimal.to_string(Decimal.round(total_amount, 2))}"]
    ]
    
    all_rows = [["Date", "Developer", "Hours", "Amount", "Description"]] ++ csv_rows ++ summary_rows
    
    csv_content = all_rows
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")

    # Generate filename with date range
    filename = generate_filename(project.name, from_date, to_date)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, csv_content)
  end

  # Get the rate and currency for a time entry based on project member settings
  defp get_entry_rate(entry, member_rates, project) do
    project_currency = project.currency || "USD"
    
    case Map.get(member_rates, entry.user_id) do
      {rate, currency} when not is_nil(rate) -> {rate, currency}
      _ -> {project.hourly_rate, project_currency}
    end
  end

  defp parse_date_range(params) do
    from = case params["from"] do
      nil -> nil
      "" -> nil
      date_str -> 
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          _ -> nil
        end
    end
    
    to = case params["to"] do
      nil -> nil
      "" -> nil
      date_str -> 
        case Date.from_iso8601(date_str) do
          {:ok, date} -> date
          _ -> nil
        end
    end
    
    {from, to}
  end

  defp format_date_range(nil, nil), do: "All Time"
  defp format_date_range(from, to) do
    from_str = if from, do: Calendar.strftime(from, "%b %d, %Y"), else: "Start"
    to_str = if to, do: Calendar.strftime(to, "%b %d, %Y"), else: "End"
    "#{from_str} - #{to_str}"
  end

  defp generate_filename(project_name, from_date, to_date) do
    # Sanitize project name for filename
    safe_name = project_name
    |> String.replace(~r/[^a-zA-Z0-9\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.downcase()
    
    date_suffix = cond do
      from_date && to_date ->
        "#{Date.to_string(from_date)}_to_#{Date.to_string(to_date)}"
      true ->
        Date.to_string(Date.utc_today())
    end
    
    "#{safe_name}_report_#{date_suffix}.csv"
  end
end
