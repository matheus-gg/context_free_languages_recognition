defmodule ContextFreeLanguagesRecognitionTest do
  use ExUnit.Case
  doctest ContextFreeLanguagesRecognition

  test "Remove Null productions" do
    assert ContextFreeLanguagesRecognition.remove_null_productions([{"S", "aMb"}, {"M", "aMb"}, {"M", ""}]) ==
      [{"S", "aMb"}, {"M", "aMb"}, {"S", "ab"}, {"M", "ab"}]
  end

  test "Remove Unit productions" do
    assert ContextFreeLanguagesRecognition.remove_unit_productions([{"S", "aA"}, {"A", "a"}, {"A", "B"}, {"B", "A"}, {"B", "bb"}]) ==
      [{"S", "aA"}, {"A", "a"}, {"B", "bb"}, {"S", "aB"}, {"S", "aA"}]
  end

  test "Substitute single terminal productions" do
    assert ContextFreeLanguagesRecognition.variable_terminal_mapper([{"S", "ab"}, {"A", "c"}], ["S", "A"], ["a", "b", "c"]) ==
      %{
        non_terminals: ["S", "A", "Ta", "Tb"],
        production_rules: [
          {"Ta", "a"},
          {"Tb", "b"},
          {"S", "TaTb"},
          {"A", "c"}
        ]
      }
  end

  test "Substitute non terminal productions greater than 2" do
    ContextFreeLanguagesRecognition.variable_non_terminal_mapper(
      %{
      production_rules: [
        {"Ta", "a"},
        {"Tb", "b"},
        {"S", "ASA"},
        {"S", "TaB"},
        {"S", "b"},
        {"B", "b"},
        {"S", "a"},
        {"S", "BSB"}
      ],
      non_terminals: ["S", "A", "B", "Ta", "Tb"]
      }
    ) ==
      %{
        non_terminals: ["S", "A", "B", "Ta", "Tb", "V1", "V2"],
        production_rules: [
          {"Ta", "a"},
          {"Tb", "b"},
          {"S", "TaB"},
          {"S", "b"},
          {"B", "b"},
          {"S", "a"},
          {"S", "AV1"},
          {"V1", "SA"},
          {"S", "BV2"},
          {"V2", "SB"}
        ]
      }
  end

  test "Context free language to Chomsky Normal Form" do
    assert ContextFreeLanguagesRecognition.cfg_to_cnf(["S", "A", "B"], ["a", "b"], [{"S", "ASA"}, {"S", "aB"}, {"S", "b"}, {"A", "B"}, {"B", "abbb"}, {"B", ""}]) ==
      %{
        non_terminals: ["S", "A", "B", "V1", "V2", "V3", "V4"],
        production_rules: [
          {"S", "SB"},
          {"S", "b"},
          {"S", "a"},
          {"B", "SV1"},
          {"V1", "SV2"},
          {"V2", "SS"},
          {"S", "AV3"},
          {"V3", "SA"},
          {"S", "BV4"},
          {"V4", "SB"}
        ]
      }
  end
	
	test "Recognise a valid word in an grammar in Chomsky Normal Form" do
		assert ContextFreeLanguagesRecognition.recognise_word([["S", "A", "B"], ["a", "b"], [{"S", "AB"}, {"A", "BB"}, {"A", "a"}, {"B", "AB"}, {"B", "b"}]], "aabbb")
	end
	
	test "Recognise a invalid word from an language in Chomsky Normal Form" do
		assert not ContextFreeLanguagesRecognition.recognise_word([["S", "A", "B"], ["a", "b"], [{"S", "AB"}, {"A", "BB"}, {"A", "a"}, {"B", "AB"}, {"B", "b"}]], "aabb")
	end
end
