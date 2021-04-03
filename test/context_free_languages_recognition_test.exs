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
        non_terminals: ["S", "A", "Ta", "Tb", "Tc"],
        production_rules: [
          {"Ta", "a"},
          {"Tb", "b"},
          {"Tc", "c"},
          {"S", "TaTb"},
          {"A", "Tc"}
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
        {"S", "Tb"},
        {"B", "Tb"},
        {"S", "Ta"},
        {"S", "BSB"}
      ],
      non_terminals: ["S", "A", "B", "Ta", "Tb"]
      }
    ) ==
      %{
        non_terminals: ["S", "A", "B", "Ta", "Tb", "V1", "V2", "V3", "V4"],
        production_rules: [
          {"Ta", "a"},
          {"Tb", "b"},
          {"S", "TaB"},
          {"S", "Tb"},
          {"B", "Tb"},
          {"S", "Ta"},
          {"V1", "AV1"},
          {"V2", "SA"},
          {"V3", "BV3"},
          {"V4", "SB"}
        ]
      }
  end

  test "Context free language to Chomsky Normal Form" do
    assert ContextFreeLanguagesRecognition.cfg_to_cnf(["S", "A", "B"], ["a", "b"], [{"S", "ASA"}, {"S", "aB"}, {"S", "b"}, {"A", "B"}, {"B", "b"}, {"B", ""}]) ==
      %{
        non_terminals: ["S", "A", "B", "Ta", "Tb", "V1", "V2", "V3", "V4"],
        production_rules: [
          {"Ta", "a"},
          {"Tb", "b"},
          {"S", "TaB"},
          {"S", "Tb"},
          {"B", "Tb"},
          {"S", "Ta"},
          {"V1", "AV1"},
          {"V2", "SA"},
          {"V3", "BV3"},
          {"V4", "SB"}
        ]
      }
  end
end
