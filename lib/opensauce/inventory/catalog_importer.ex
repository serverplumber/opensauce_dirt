defmodule OpenSauce.Inventory.CatalogImporter do
  @moduledoc """
  Imports supplier catalogs from PDF files using Claude.

  Two-phase: extract/1 calls the API and returns a preview list of maps;
  commit/3 writes them to the database after the user approves.
  """

  @api_url "https://api.anthropic.com/v1/messages"
  @model "claude-opus-4-7"

  @prompt """
  Extract every product from this nursery supplier catalog PDF.

  Return a JSON array. Each element is an object with these keys:

  - "sku"                 — product code exactly as printed (string, required)
  - "name"                — common name in English; translate from French if needed (string, required)
  - "latin_name"          — genus and species only, no cultivar (e.g. "Acer ginnala") (string or null)
  - "cultivar"            — cultivar name only, no quotes or apostrophes (e.g. "Flame") (string or null)
  - "category"            — one of: "plant", "amendment", "container", "other"
  - "format_description"  — size/grade/format verbatim from catalog (e.g. "tige, 100mm WB", "Pots 1 gallon (3 L)", "30L bag") (string or null)
  - "unit_price"          — price as a decimal number; null if "prix sur demande" or not listed (number or null)
  - "available"           — false only if explicitly marked discontinued or unavailable (boolean)
  - "notes"               — any other relevant information (string or null)

  Rules:
  - One object per distinct SKU. If the same plant appears in multiple sizes/grades, each is a separate object.
  - Do not invent data. If a field is not in the catalog, use null.
  - Prices like "845,00" (French) should become 845.00.
  - Return ONLY the JSON array. No markdown, no explanation.
  """

  @doc """
  Sends a PDF binary to Claude and returns a preview list of extracted maps.
  Does not write to the database.
  """
  def extract(pdf_binary) when is_binary(pdf_binary) do
    api_key = Application.get_env(:opensauce, :anthropic_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, "ANTHROPIC_API_KEY is not set — add it to .envrc.local and restart the server"}
    else
      do_extract(pdf_binary, api_key)
    end
  end

  defp do_extract(pdf_binary, api_key) do
    body = %{
      model: @model,
      max_tokens: 8096,
      messages: [
        %{
          role: "user",
          content: [
            %{
              type: "document",
              source: %{
                type: "base64",
                media_type: "application/pdf",
                data: Base.encode64(pdf_binary)
              }
            },
            %{type: "text", text: @prompt}
          ]
        }
      ]
    }

    case Req.post(@api_url,
           json: body,
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        parse_response(text)

      {:ok, %{status: status, body: body}} ->
        {:error, "API returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Writes a previewed item list to the database under the given catalog.
  Returns {:ok, %{created: n, failed: n}}.
  """
  def commit(items, supplier_catalog_id, opts \\ []) when is_list(items) do
    actor = Keyword.get(opts, :actor)
    tenant = Keyword.get(opts, :tenant)

    results =
      Enum.map(items, fn item ->
        attrs = %{
          supplier_catalog_id: supplier_catalog_id,
          sku: item["sku"] || "UNKNOWN",
          name: item["name"] || item["latin_name"] || "Unknown",
          latin_name: item["latin_name"],
          cultivar: item["cultivar"],
          category: parse_category(item["category"]),
          format_description: item["format_description"],
          unit_price: parse_price(item["unit_price"]),
          available: Map.get(item, "available", true),
          notes: item["notes"],
          min_order_qty: 1
        }

        OpenSauce.Inventory.create_supplier_catalog_item(attrs, actor: actor, tenant: tenant)
      end)

    created = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    {:ok, %{created: created, failed: failed}}
  end

  defp parse_response(text) do
    clean =
      text
      |> String.trim()
      |> strip_fences()

    case Jason.decode(clean) do
      {:ok, list} when is_list(list) -> {:ok, list}
      {:ok, _} -> {:error, "Expected a JSON array from the model"}
      {:error, err} -> {:error, "Could not parse model response: #{Exception.message(err)}"}
    end
  end

  defp strip_fences("```json" <> rest), do: rest |> String.trim_trailing("```") |> String.trim()
  defp strip_fences("```" <> rest), do: rest |> String.trim_trailing("```") |> String.trim()
  defp strip_fences(text), do: text

  defp parse_category("plant"), do: :plant
  defp parse_category("amendment"), do: :amendment
  defp parse_category("container"), do: :container
  defp parse_category(_), do: :other

  defp parse_price(n) when is_number(n) and n >= 0, do: Decimal.new("#{n}")
  defp parse_price(_), do: nil
end
