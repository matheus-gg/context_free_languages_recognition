defmodule ContextFreeLanguagesRecognition do
  @moduledoc """
  Documentation for `ContextFreeLanguagesRecognition`.
  """

  def cfg_to_cnf(non_terminals, terminals, production_rules) do
    remove_null_productions(production_rules)
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
    target_productions = production_rules -- only_terminals
    new_prod_rules = Enum.reduce(terminals, [], fn x, acc -> acc ++ [{"T#{x}", x}] end)
    replaced_prod_rules = Enum.reduce(target_productions, [], fn x, acc -> acc ++ [{elem(x, 0), String.replace(elem(x, 1), terminals, fn y -> "T#{y}" end)}] end)
    %{:production_rules => new_prod_rules ++ replaced_prod_rules ++ only_terminals, :non_terminals => non_terminals ++ Enum.reduce(new_prod_rules, [], fn x, acc -> acc ++ [elem(x, 0)] end)}
  end

  def variable_non_terminal_mapper(%{:production_rules => production_rules, :non_terminals => non_terminals}, index \\ 1) do
    target_production = Enum.find(production_rules, fn x -> String.length(elem(x, 1)) >= 3 and Enum.all?(String.graphemes(elem(x, 1)), fn y -> is_non_terminal(y) and (not is_str_integer(y)) end)  end)
    case (target_production == nil) do
      true -> %{:production_rules => production_rules, :non_terminals => non_terminals}
      false ->
        filtered_productions = production_rules -- [target_production]
        final_elements = Enum.drop(String.graphemes(elem(target_production, 1)), String.length(elem(target_production, 1)) - 2)
        other_elements = String.graphemes(elem(target_production, 1)) -- final_elements
        new_productions = Enum.reduce(other_elements, [], fn x, acc -> acc ++ [{"V#{index + length(acc)}", "#{x}V#{index + length(acc)}"}] end)
        {:ok, last_elem} = Enum.fetch(new_productions, -1)
        last_index = String.to_integer(String.replace(elem(last_elem, 0), "V", ""))
        last_production = {"V#{last_index + 1}", "#{Enum.at(final_elements, 0)}#{Enum.at(final_elements, 1)}"}
        new_non_terminals = Enum.reduce(new_productions, [], fn x, acc -> acc ++ [elem(x, 0)] end)
        variable_non_terminal_mapper(%{:production_rules => filtered_productions ++ new_productions ++ [last_production], :non_terminals => non_terminals ++ new_non_terminals ++ ["V#{last_index + 1}"]}, last_index + 2)
    end
  end

	def recognise_word(grammar, word) do
		non_terminals = Enum.at(grammar, 0)
		terminals = Enum.at(grammar, 1)
		production_rules = Enum.at(grammar, 2)
		grammar_in_cnf = ContextFreeLanguagesRecognition.cfg_to_cnf(non_terminals, terminals, production_rules)
		CheckProduction.start(grammar_in_cnf.production_rules)
		production_rules_for_this_word = CheckProduction.check_word(word)
		Enum.member?(production_rules_for_this_word, "S")
	end
end

defmodule CheckProduction do
  use Agent

  def start(production_rules) do
		Agent.start_link(fn -> production_rules end, name: :production_rules)
    Agent.start_link(fn -> %{} end, name: :words_already_checked)
  end
	
  def check(word, split_at) do
		cached_value = Agent.get(:words_already_checked, &(Map.get(&1, word)))
		if cached_value do
      cached_value
		else
			production_rules = Agent.get(:production_rules, & &1)
			cond do 
				String.length(word) == 1 ->
					production_rule = Enum.filter(production_rules, fn x -> elem(x, 1) == word end)
					if production_rule do
						production_rule = Enum.reduce(production_rule, [], fn x, acc -> acc ++ [elem(x, 0)] end)
						Enum.uniq(production_rule)
						Agent.update(:words_already_checked, &(Map.put(&1, word, production_rule)))
						production_rule
					else
						[]
					end
				true ->
					word_splited = String.split_at(word, split_at)
					prefix = elem(word_splited, 0)
					suffix = elem(word_splited, 1)
					if prefix != "" and suffix != "" do
						prefix_production = check(prefix, 1)
						suffix_production = check(suffix, 1)
						prefix_and_suffix_pairs = Enum.reduce(prefix_production, [], fn x, acc -> acc ++ Enum.reduce(suffix_production, [], fn y, acc2 -> acc2 ++ ["#{x}#{y}"] end ) end)
						production_rule = Enum.reduce(prefix_and_suffix_pairs, [], fn pair , acc -> acc ++ Enum.filter(production_rules, fn production_rule -> elem(production_rule, 1) == pair end) end)
						if production_rule do
							production_rule = Enum.reduce(production_rule, [], fn x, acc -> acc ++ [elem(x, 0)] end)
							production_rule = production_rule ++ check(word, split_at + 1)
							production_rule = Enum.uniq(production_rule)
							Agent.update(:words_already_checked, &(Map.put(&1, word, production_rule)))
							production_rule
						else
							[]
						end
					else
						[]
					end
			end
		end
		
  end
	
	def check_word(word) do
		CheckProduction.check(word, 1)
	end
	
end
