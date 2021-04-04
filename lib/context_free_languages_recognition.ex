defmodule ContextFreeLanguagesRecognition do
	use Agent
  @moduledoc """
  This module implements strings recognition for context free languages. Is divided in two parts:
  * A set of funcions to make the transformation of the input context free grammar into an equivalent Chomsky Normal Form grammar.
  * Another set of functions to implement the CYK algorithm to determine if the input string is accepted by the converted Chomsky Normal Form grammar.

  A grammar is said to be in Chomsky Normal Form if all of its production rules are of the form: `A -> BC` or `A -> a`. The transformation of the input grammar
  into an equivalent Chomsky Normal Form grammar is based on a central function. It receives the non terminals, terminals and production rules and applies
  a set of changes in order to accomplish the transformation. The changes consist of removing null productions,removing unit productions, sanitizing
  productions (remove duplicates and dumb productions), changing right hand side terminals adding a new production for them (when applicable) and
  changing right hand side non terminal productions with length larger or equal 3. After all these changes, the new grammar is a Chomsky normal form grammar
  equivalent to the input grammar.

  Some conventions were applied to make the validation and transformation process easier. The start symbol will always be `S`. The valid terminals are
  all the lower case letters of the latin alphabet. The valid non terminals are all the upper case letters of the latin alphabet, except the `T` and `V`.
  The new production rules made for the righ hand side terminals are constructed as `Tx -> x`. The new production rules made for the right hand side non
  terminals bigger than or equal 3 are constructed with the `Vn` non terminal, iex. `B -> ABC` generates `B -> AV1, V1 -> BC`.

  The CYK algorithm is a parsing algorithm for context free grammars, used to determine if a string is accepted by the grammar. The input grammar must
  be in the Chomsky Normal Form. The algorithm is based in dynamic programming, and it's worst case running time is `O(n^3*|G|)`. Basically the CYK split the word
  into two parts the prefix and suffix and check the production rules of them and join to see if there is a formation that can generate the joined non terminal final element
  if there is then add to a list of possible formation rule when splited there.And after that he continues to split the word in ever possible position and do this.
  After all splits then he join all solution found and check if the start symbol is there. if it is then that word can be generated with this production rules.
  """

	@doc """
	This function start the Agent and initialize with two list one containg the profuction rules, and the another containing words already checked.
	## Parameters
    - **production_rules**: the production rules in chomsky Normal Form.
	"""
  def start(production_rules) do
		Agent.start_link(fn -> production_rules end, name: :production_rules)
    Agent.start_link(fn -> %{} end, name: :words_already_checked)
  end

  @doc """
  Central function to perform the Chomsky Normal Form transformation. Receives the input grammar parameters and uses the pipeline operator to sequentially
  call the transformation functions with the input parameters. Returns the new grammar, equivalent to the one from the input, but in CNF.

  ## Parameters
    - **non_terminals**: The list of non terminals of the input grammar.
    - **terminals**: The list of terminals of the input grammar.
    - **production_rules**: A list of tuples representing the production rules. The form o the tuples is `{"S", "aB"}`, where the first argument is the left hand side of the production rule, and the second argument the right hand side of the production rule.
  """
  def cfg_to_cnf(non_terminals, terminals, production_rules) do
    remove_null_productions(production_rules)
    |> remove_unit_productions()
    |> sanitize_productions()
    |> variable_terminal_mapper(non_terminals, terminals)
    |> variable_non_terminal_mapper()
  end

  @doc """
  Determines if a char is a terminal. Returns true if is a terminal, and false otherwise.

  ## Parameters
    - **char**: The char to be evaluated.
  """
  def is_terminal(char) do
    String.downcase(char) == char
  end

  @doc """
  Determines if a char is a non terminal. Returns true if is a non terminal, and false otherwise.

  ## Parameters
    - **char**: The char to be evaluated.
  """
  def is_non_terminal(char) do
    String.upcase(char) == char
  end

  @doc """
  Determines if a char is string representation of a integer. Returns true if is an integer, and false otherwise.

  ## Parameters
    - **char**: The char to be evaluated.
  """
  def is_str_integer(char) do
    case Integer.parse(char) do
      {_, ""} -> true
      _ -> false
    end
  end

  @doc """
  Removes the null productions from the production rules recursivelly. The null productions are represented by `{"N", ""}`. Returns the new production rules.

  ## Parameters
    - **production_rules**: A list of tuples representing the production rules. The form o the tuples is `{"S", "aB"}`, where the first argument is the left hand side of the production rule, and the second argument the right hand side of the production rule..
  """
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

  @doc """
  Removes the unit productions from the production rules recursivelly. The unit productions are represented by `{"N", "N"}`. Returns the new production rules.

  ## Parameters
    - **production_rules**: A list of tuples representing the production rules. The form o the tuples is `{"S", "aB"}`, where the first argument is the left hand side of the production rule, and the second argument the right hand side of the production rule..
  """
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

  @doc """
  Sanitizes the production rules, removing duplicated rules and rules of the form `A -> A`. Returns the new production rules.

  ## Parameters
    - **production_rules**: A list of tuples representing the production rules. The form o the tuples is `{"S", "aB"}`, where the first argument is the left hand side of the production rule, and the second argument the right hand side of the production rule..
  """
  def sanitize_productions(production_rules) do
    remove_dumb_transitions = Enum.filter(production_rules, fn x -> elem(x, 0) != elem(x, 1) end)
    Enum.uniq(remove_dumb_transitions)
  end

  @doc """
  Changes the productions with terminals on the right hand side. If there is a rule mapping a non terminal to a terminal, no additional rules are generated.
  Otherwise, a new rule is produced for each non terminal found on the right hand side, on the form `{"Tx", "x"}`, and the rhs terminals are then substituted for the equivalent new generated terminal.
  The return of this function is a map with the new production rules and the new non terminals.

  ## Parameters
    - **production_rules**: A list of tuples representing the production rules. The form o the tuples is `{"S", "aB"}`, where the first argument is the left hand side of the production rule, and the second argument the right hand side of the production rule.
    - **non_terminals**: The list of non terminals of the input grammar.
    - **terminals**: The list of terminals of the input grammar.
  """
  def variable_terminal_mapper(production_rules, non_terminals, terminals) do
    only_terminal_rules = Enum.filter(production_rules, fn x -> String.length(elem(x, 1)) == 1 and is_terminal(elem(x, 1)) end)
    only_terminal_map = Enum.reduce(only_terminal_rules, Map.new(), fn x, acc -> Map.put(acc, elem(x, 1), elem(x, 0)) end)
    only_non_terminal_rules = Enum.filter(production_rules, fn x -> Enum.all?(String.graphemes(elem(x, 1)), fn y -> is_non_terminal(y) end) end)
    filter_terminal_prod = production_rules -- only_terminal_rules
    target_productions =  filter_terminal_prod -- only_non_terminal_rules
    only_terminals = Enum.reduce(only_terminal_rules, [], fn x, acc -> acc ++ [elem(x, 1)] end)
    new_prod_rules = Enum.reduce(terminals -- only_terminals, [], fn x, acc -> acc ++ [{"T#{x}", x}] end)
    replaced_prod_rules = Enum.reduce(target_productions, [], fn x, acc -> case String.contains?(elem(x, 1), only_terminals) do
      true ->
        replace_only_terminals = String.replace(elem(x, 1), only_terminals, fn y -> only_terminal_map[y] end)
        case String.contains?(replace_only_terminals, terminals -- only_terminals) do
          true -> acc ++ [{elem(x, 0), String.replace(replace_only_terminals, terminals -- only_terminals, fn y -> "T#{y}" end)}]
          false -> acc ++ [{elem(x, 0), replace_only_terminals}]
        end
      false -> acc ++ [{elem(x, 0), String.replace(elem(x, 1), terminals -- only_terminals, fn y -> "T#{y}" end)}]
      end
    end)
    %{:production_rules => new_prod_rules ++ replaced_prod_rules ++ only_terminal_rules ++ only_non_terminal_rules, :non_terminals => non_terminals ++ Enum.reduce(new_prod_rules, [], fn x, acc -> acc ++ [elem(x, 0)] end)}
  end

  @doc """
  Changes the productions with non terminals on the right hand side and length greater or equal 3. If there is a rule mapping a non terminal to three or more non terminals, this rule is broken into two or more new rules.
  The new rules are generated with the non terminal `V` followed by an index. Iex: `{"S", "ABCD"}` is broken into `[{"S", "AV1"}, {"V1", "BV2"}, {"V2", "CD"}}]`.
  The return of this function is a map with the new production rules and the new non terminals.

  ## Parameters
    - **%{:production_rules => production_rules, :non_terminals => non_terminals}**: A map with the production_rules and non_terminals to be changed.
    - **index**: The index used to generate the new non terminals `Vn`. Starts with 1 and is incremented for each `Vn` generated.
  """
  def variable_non_terminal_mapper(%{:production_rules => production_rules, :non_terminals => non_terminals}, index \\ 1) do
    target_production = Enum.find(production_rules, fn x -> String.length(elem(x, 1)) >= 3 and Enum.all?(String.graphemes(elem(x, 1)), fn y -> is_non_terminal(y) and (not is_str_integer(y)) end)  end)
    case (target_production == nil) do
      true ->
        t_productions = Enum.filter(production_rules, fn x -> String.contains?(elem(x, 1), "T") end)
        target_t_production = Enum.find(t_productions, fn x -> String.length(elem(x, 1)) - Enum.count(String.graphemes(elem(x, 1)), fn y -> y == "T" end) - Enum.count(String.graphemes(elem(x, 1)), fn y -> y == "V" end) - Enum.count(String.graphemes(elem(x, 1)), fn y -> is_str_integer(y) end) >= 3 end)
        case (target_t_production == nil) do
          true -> %{:production_rules => production_rules, :non_terminals => Enum.uniq(non_terminals)}
          false ->
            filtered_t_productions = production_rules -- [target_t_production]
            chunked_production = Enum.reduce(String.graphemes(elem(target_t_production, 1)), [], fn x, acc -> case (is_non_terminal(x)) do
              true -> acc ++ [x]
              false ->
                last_element = Enum.at(acc, -1)
                acc ++ ["#{last_element}#{x}"]
              end
            end)
            clean_chunked_prod = Enum.reject(chunked_production, fn x -> x == "T" end)
            final_elem = Enum.drop(clean_chunked_prod, Enum.count(clean_chunked_prod) -2)
            other_elem = clean_chunked_prod -- final_elem
            new_prods = Enum.reduce(other_elem, [], fn x, acc -> case Enum.empty?(acc) do
              true -> acc ++ [{elem(target_t_production, 0), "#{x}V#{index + length(acc)}"}]
              false -> acc ++ [{"V#{index + length(acc) - 1}", "#{x}V#{index + length(acc)}"}]
              end
            end)
            {:ok, last_element} = Enum.fetch(new_prods, -1)
            last_idx = case String.contains?(elem(last_element, 0), "V") do
              true -> String.to_integer(String.replace(elem(last_element, 0), "V", ""))
              false -> index - 1
            end
            last_prod = {"V#{last_idx + 1}", "#{Enum.at(final_elem, 0)}#{Enum.at(final_elem, 1)}"}
            new_non_term = Enum.reduce(new_prods, [], fn x, acc -> acc ++ [elem(x, 0)] end)
            variable_non_terminal_mapper(%{:production_rules => filtered_t_productions ++ new_prods ++ [last_prod], :non_terminals => non_terminals ++ new_non_term ++ ["V#{last_idx + 1}"]}, last_idx + 2)
        end
      false ->
        filtered_productions = production_rules -- [target_production]
        final_elements = Enum.drop(String.graphemes(elem(target_production, 1)), String.length(elem(target_production, 1)) - 2)
        other_elements = String.graphemes(elem(target_production, 1)) -- final_elements
        new_productions = Enum.reduce(other_elements, [], fn x, acc -> case Enum.empty?(acc) do
          true -> acc ++ [{elem(target_production, 0),"#{x}V#{index + length(acc)}"}]
          false -> acc ++ [{"V#{index + length(acc) - 1}", "#{x}V#{index + length(acc)}"}]
          end
        end)
        {:ok, last_elem} = Enum.fetch(new_productions, -1)
        last_index = case String.contains?(elem(last_elem, 0), "V") do
          true -> String.to_integer(String.replace(elem(last_elem, 0), "V", ""))
          false -> index - 1
        end
        last_production = {"V#{last_index + 1}", "#{Enum.at(final_elements, 0)}#{Enum.at(final_elements, 1)}"}
        new_non_terminals = Enum.reduce(new_productions, [], fn x, acc -> acc ++ [elem(x, 0)] end)
        variable_non_terminal_mapper(%{:production_rules => filtered_productions ++ new_productions ++ [last_production], :non_terminals => non_terminals ++ new_non_terminals ++ ["V#{last_index + 1}"]}, last_index + 2)
    end
  end

	@doc """
	Check the rules that produce this decomposition of word at specific position and their subsequentials.
	## Parameters
    - **word**: The word that want to analyze the decomposition.
    - **split_at**: The position of word where is going to be splited.
	"""
	def check_decomposition(word, split_at) do
		# First I check if this word already exists in cache, if already exist return the cached value else process the word
		cached_value = Agent.get(:words_already_checked, &(Map.get(&1, word)))
		if cached_value do
			cached_value
		else
			production_rules = Agent.get(:production_rules, & &1)
			cond do
				# I check if the length of word is 1 if it is just get the production rules for this word from the production rules cache the value and then return
				String.length(word) == 1 ->
					production_rule = Enum.filter(production_rules, fn x -> elem(x, 1) == word end)
					production_rule = Enum.reduce(production_rule, [], fn x, acc -> acc ++ [elem(x, 0)] end)
					Enum.uniq(production_rule)
					Agent.update(:words_already_checked, &(Map.put(&1, word, production_rule)))
					production_rule
				true ->
					# if the length of word is higher than 1 then the word is splited in 2 parts, the first one is the prefix and the other is suffix,
					word_splited = String.split_at(word, split_at)
					prefix = elem(word_splited, 0)
					suffix = elem(word_splited, 1)
					if prefix != "" and suffix != "" do
						prefix_production = check_decomposition(prefix, 1)
						suffix_production = check_decomposition(suffix, 1)
						# I check the production rules of both and then I join all prefix_production and suffix_production possibilities
						prefix_and_suffix_pairs = Enum.reduce(prefix_production, [], fn x, acc -> acc ++ Enum.reduce(suffix_production, [], fn y, acc2 -> acc2 ++ ["#{x}#{y}"] end ) end)
						# and then i check in the production rules all the pairs that belong to production rules
						production_rule = Enum.reduce(prefix_and_suffix_pairs, [], fn pair , acc -> acc ++ Enum.filter(production_rules, fn production_rule -> elem(production_rule, 1) == pair end) end)
						if production_rule do
							production_rule = Enum.reduce(production_rule, [], fn x, acc -> acc ++ [elem(x, 0)] end)
							# I check the next decomposition of the word and join with the one i got here
							production_rule = production_rule ++ check_decomposition(word, split_at + 1)
							production_rule = Enum.uniq(production_rule)
							if split_at == 1 do
								# when the first got back all other decomposition I save in cache
								Agent.update(:words_already_checked, &(Map.put(&1, word, production_rule)))
							end
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

	@doc """
	I got a top-bottom aproach so I get the whole word first and try to find the subtring production rules.
	(if image is too small click to view image in another tab)
	This image represent the function calling the top one first.
	Represented as "1) a|abb": 
    - The "1)" represent the order of calling the function but not necessary the returning order because in this case the 1) is the last to return.
    - The "|" represent where I'm spliting the word

	![](../images/check_word.png)
	## Parameters
    - **word**: The word that want to analyze with the production rule.
	"""
	def check_word(word) do
		check_decomposition(word, 1)
	end

	@doc """
	Recognise the word with a context free language.
	## Parameters
    - **grammar**: Grammar in context free langage.
    - **word**: The word that want to analyze with the grammar.
	"""
	def recognise_word(grammar, word) do
		non_terminals = Enum.at(grammar, 0)
		terminals = Enum.at(grammar, 1)
		production_rules = Enum.at(grammar, 2)
		# convert the grammar to Chomsky Normal Form
		grammar_in_cnf = cfg_to_cnf(non_terminals, terminals, production_rules)
		start(grammar_in_cnf.production_rules)
		production_rules_for_this_word = check_word(word)
		Enum.member?(production_rules_for_this_word, "S")
	end
end
