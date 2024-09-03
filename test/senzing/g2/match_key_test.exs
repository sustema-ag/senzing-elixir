defmodule Senzing.G2.MatchKeyTest do
  use ExUnit.Case

  alias Senzing.G2.MatchKey

  doctest Senzing.G2.MatchKey

  describe inspect(&MatchKey.parse/1) do
    test "works" do
      assert MatchKey.parse("+LEI(:IS_DIRECTLY_CONSOLIDATED_BY,IS_ULTIMATELY_CONSOLIDATED_BY)") ==
               {:ok,
                [
                  %{
                    signal: :positive,
                    attribute_name: "LEI",
                    relationship: %{
                      direction: :recipient,
                      types: ["IS_DIRECTLY_CONSOLIDATED_BY", "IS_ULTIMATELY_CONSOLIDATED_BY"]
                    }
                  }
                ]}

      assert MatchKey.parse("+NAME+GROUP_ASSOCIATION+REGISTRATION_COUNTRY+LEI_NUMBER") ==
               {:ok,
                [
                  %{signal: :positive, attribute_name: "NAME"},
                  %{signal: :positive, attribute_name: "GROUP_ASSOCIATION"},
                  %{signal: :positive, attribute_name: "REGISTRATION_COUNTRY"},
                  %{signal: :positive, attribute_name: "LEI_NUMBER"}
                ]}

      assert MatchKey.parse(
               "+ADDRESS+GROUP_ASSOCIATION+REGISTRATION_COUNTRY+LEI(:IS_DIRECTLY_CONSOLIDATED_BY,IS_ULTIMATELY_CONSOLIDATED_BY)-REGISTRATION_DATE-LEI_NUMBER"
             ) ==
               {:ok,
                [
                  %{signal: :positive, attribute_name: "ADDRESS"},
                  %{signal: :positive, attribute_name: "GROUP_ASSOCIATION"},
                  %{signal: :positive, attribute_name: "REGISTRATION_COUNTRY"},
                  %{
                    signal: :positive,
                    attribute_name: "LEI",
                    relationship: %{
                      direction: :recipient,
                      types: ["IS_DIRECTLY_CONSOLIDATED_BY", "IS_ULTIMATELY_CONSOLIDATED_BY"]
                    }
                  },
                  %{signal: :negative, attribute_name: "REGISTRATION_DATE"},
                  %{signal: :negative, attribute_name: "LEI_NUMBER"}
                ]}

      assert MatchKey.parse("") ==
               {:ok, []}

      assert {:error,
              %MatchKey.ParseError{message: "expected signal" <> _rest, subject: "invalid", rest: "invalid", offset: 0}} =
               MatchKey.parse("invalid")
    end
  end

  describe inspect(&MatchKey.parse!/1) do
    test "works" do
      assert MatchKey.parse!("+NAME") == [%{signal: :positive, attribute_name: "NAME"}]

      assert_raise MatchKey.ParseError, ~r/expected signal/, fn ->
        MatchKey.parse!("invalid")
      end
    end
  end
end
