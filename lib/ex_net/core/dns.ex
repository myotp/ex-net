defmodule ExNet.Core.Dns do
  @dns_query_flag 0x01_00

  @dns_query_type_A 0x00_01
  @dns_query_class_IN 0x00_01

  defstruct [
    :tid,
    :flags,
    :questions,
    :answer_RRs,
    :authority_RRs,
    :additional_RRs,
    :queries,
    :answers
  ]

  def only_parse_one_query_and_ip_addr_answer(
        <<tid::16-big, flags::16-big, questions::16-big, answer_RRs::16-big,
          authority_RRs::16-big, additional_RRs::16-big, rest::binary>>
      ) do
    case {questions, answer_RRs} do
      {1, 1} ->
        try do
          {queries, rest} = parse_queries(rest, questions)
          {answers, _} = parse_answers(rest, answer_RRs)

          %__MODULE__{
            tid: tid,
            flags: flags,
            questions: questions,
            answer_RRs: answer_RRs,
            authority_RRs: authority_RRs,
            additional_RRs: additional_RRs,
            queries: queries,
            answers: answers
          }
        rescue
          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp parse_queries(bin, n, acc \\ [])

  defp parse_queries(bin, 0, acc) do
    {acc, bin}
  end

  defp parse_queries(bin, n, acc) do
    {name, <<type::big-16, class::big-16, rest::binary>>} = parse_name(bin)
    query = %{name: name, type: type_i2a(type), class: class_i2a(class)}
    parse_queries(rest, n - 1, [query | acc])
  end

  defp parse_name(bin, acc \\ [])

  defp parse_name(<<0, rest::binary>>, acc) do
    name =
      acc
      |> Enum.reverse()
      |> Enum.join(".")

    {name, rest}
  end

  defp parse_name(<<len::8, label::binary-size(len), rest::binary>>, acc) do
    parse_name(rest, [label | acc])
  end

  defp type_i2a(0x00_01), do: :A

  defp class_i2a(0x00_01), do: :IN

  defp parse_answers(
         <<_label_start::8, _offset::8, _type::16, _class::16, _ttl::32, len::big-16,
           addr::big-size(len * 8), rest::binary>>,
         1
       ) do
    {[%{addr: addr}], rest}
  end

  def request_ip_packet(url) do
    queries =
      <<to_label(url)::binary, 0::8, @dns_query_type_A::16-big, @dns_query_class_IN::16-big>>

    <<
      transaction_id()::16-big,
      @dns_query_flag::16-big,
      # questions
      1::16-big,
      # answers
      0::16-big,
      # Authority RRs
      0::16-big,
      # Additional RRs
      0::16-big,
      queries::binary
    >>
  end

  defp to_label(url) do
    url
    |> String.split(".")
    |> Enum.map(fn s -> <<String.length(s)::8, s::binary>> end)
    |> Enum.join()
  end

  defp transaction_id(), do: Enum.random(1..0xFF_FF)
end
