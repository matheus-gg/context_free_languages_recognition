defmodule ContextFreeLanguagesRecognition do
  @moduledoc """
  Documentation for `ContextFreeLanguagesRecognition`.
  """

  def cfg_to_cnf(non_terminals, terminals, production_rules) do
    cnf = remove_null_productions(production_rules)
    |> remove_unit_productions()
    |> sanitize_productions()
    |> variable_terminal_mapper(non_terminals, terminals)
    |> variable_non_terminal_mapper()
  end

  def is_terminal(char) do
    String.downcase(char) == char
  end

  def is_non_terminal(char) do
    String.upcase(char) == char
  end

  def is_str_integer(char) do
    case Integer.parse(char) do
      {_, ""} -> true
      _ -> false
    end
  end

  def remove_null_productions(production_rules) do
    null_productions = Enum.filter(production_rules, fn x -> elem(x, 1) == "" end)
    case (Enum.empty?(null_productions)) do
      true -> production_rules
      false ->
        non_empty_prod_rules = production_rules -- null_productions
        empty_non_terminals = Enum.reduce(null_productions, [], fn x, acc -> acc ++ [elem(x, 0)] end)
        target_productions = Enum.filter(non_empty_prod_rules, fn x -> String.contains?(elem(x, 1), empty_non_terminals) end)
        new_productions = Enum.reduce(target_productions, [], fn x, acc -> acc ++ [{elem(x, 0), String.replace(elem(x, 1), empty_non_terminals, "")}] end)
        remove_null_productions(non_empty_prod_rules ++ new_productions)
    end
  end

  def remove_unit_productions(production_rules) do
    unit_production = Enum.find(production_rules, fn x -> String.length(elem(x, 1)) == 1 and is_non_terminal(elem(x, 1)) end)
    case (unit_production == nil) do
      true -> production_rules
      false ->
        non_unit_prod_rules = production_rules -- [unit_production]
        target_productions = Enum.filter(non_unit_prod_rules, fn x -> String.contains?(elem(x, 1), elem(unit_production, 0)) end)
        new_productions = Enum.reduce(target_productions, [], fn x, acc -> acc ++ [{elem(x, 0), String.replace(elem(x, 1), elem(unit_production, 0), elem(unit_production, 1))}] end)
        remove_dumb_transitions = Enum.filter(non_unit_prod_rules ++ new_productions, fn x -> elem(x, 0) != elem(x, 1) end)
        remove_unit_productions(remove_dumb_transitions)
    end
  end

  def sanitize_productions(production_rules) do
    remove_dumb_transitions = Enum.filter(production_rules, fn x -> elem(x, 0) != elem(x, 1) end)
    Enum.uniq(remove_dumb_transitions)
  end

  def variable_terminal_mapper(production_rules, non_terminals, terminals) do
    only_terminals = Enum.filter(production_rules, fn x -> String.length(elem(x, 1)) == 1 and is_terminal(elem(x, 1)) end)
    terminals = terminals -- only_terminals

    new_prod_rules = Enum.reduce(terminals, [], fn x, acc -> acc ++ [{"T#{x}", x}] end)
    replaced_prod_rules = Enum.reduce(production_rules, [], fn x, acc -> acc ++ [{elem(x, 0), String.replace(elem(x, 1), terminals, fn y -> "T#{y}" end)}] end)
    %{:production_rules => new_prod_rules ++ replaced_prod_rules, :non_terminals => non_terminals ++ Enum.reduce(new_prod_rules, [], fn x, acc -> acc ++ [elem(x, 0)] end)}
  end

  def variable_non_terminal_mapper(%{:production_rules => production_rules, :non_terminals => non_terminals}, index \\ 1) do
    target_production = Enum.find(production_rules, fn x -> String.length(elem(x, 1)) >= 3 and Enum.all?(String.graphemes(elem(x, 1)), fn y -> is_non_terminal(y) and (not is_str_integer(y)) end)  end)
    case (target_production == nil) do
      true -> %{:production_rules => production_rules, :non_terminals => non_terminals}
      false ->
        filtered_productions = production_rules -- [target_production]
        final_elements = Enum.drop(String.graphemes(elem(target_production, 1)), String.length(elem(target_production, 1)) - 2)
        other_elements = String.graphemes(elem(target_production, 1)) -- final_elements
        new_productions = Enum.reduce(other_elements, [], fn x, acc -> acc ++ [{"V#{index + Enum.find_index(other_elements, fn y -> y == x end)}", "#{other_elements}V#{index + Enum.find_index(other_elements, fn y -> y == x end)}"}] end)
        {:ok, last_elem} = Enum.fetch(new_productions, -1)
        last_index = String.to_integer(String.replace(elem(last_elem, 0), "V", ""))
        last_production = {"V#{last_index + 1}", "#{Enum.at(final_elements, 0)}#{Enum.at(final_elements, 1)}"}
        new_non_terminals = Enum.reduce(new_productions, [], fn x, acc -> acc ++ [elem(x, 0)] end)
        variable_non_terminal_mapper(%{:production_rules => filtered_productions ++ new_productions ++ [last_production], :non_terminals => non_terminals ++ new_non_terminals ++ ["V#{last_index + 1}"]}, last_index + 2)
    end
  end
end
