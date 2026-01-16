# TODO: Remove module when requiring Phoenix 1.7.0
unless Pow.dependency_vsn_match?(:phoenix, ">= 1.7.0") do
defmodule Pow.Phoenix.HTML.Bootstrap do
  @moduledoc false

  @form_template EEx.compile_string(
    """
    <%%= form_for @changeset, @action, [as: :user], fn f -> %>
      <%%= if @changeset.action do %>
        <div class="alert alert-danger">
          <p>Oops, something went wrong! Please check the errors below.</p>
        </div>
      <%% end %>
    <%= for {label, input, error} <- inputs, input do %>
      <div class="form-group">
        <%= label %>
        <%= input %>
        <%= error %>
      </div>
    <% end %>
      <div class="form-group">
        <%%= submit <%= inspect button_label %>, class: "btn btn-primary" %>
      </div>
    <%% end %>
    """)

  def render_form(inputs, opts \\ []) do
    button_label = Keyword.get(opts, :button_label, "Submit")

    inputs = for {type, key} <- inputs, do: input(type, key)

    unquote(@form_template)
  end

  defp input(:text, key) do
    {label(key), ~s(<%= text_input f, #{inspect_key(key)}, class: "form-control" %>), error(key)}
  end
  defp input(:password, key) do
    {label(key), ~s(<%= password_input f, #{inspect_key(key)}, class: "form-control" %>), error(key)}
  end

  defp inspect_key({:changeset, :pow_user_id_field}), do: "Pow.Ecto.Schema.user_id_field(@changeset)"
  defp inspect_key(key), do: inspect(key)

  defp label(key) do
    ~s(<%= label f, #{inspect_key(key)}, class: "control-label" %>)
  end

  defp error(key) do
    ~s(<%= error_tag f, #{inspect_key(key)} %>)
  end
end
end
