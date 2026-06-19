# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.CRM.Changes.AssignInvoiceNumber do
  @moduledoc false
  use Ash.Resource.Change

  import Ecto.Query

  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      org_id = Ash.Changeset.get_attribute(changeset, :organisation_id)

      {1, [new_next]} =
        from(o in "accounts_organisations",
          where: o.id == ^org_id,
          update: [inc: [next_invoice_number: 1]],
          select: o.next_invoice_number
        )
        |> OpenSauce.Repo.update_all([])

      invoice_number = new_next - 1

      changeset
      |> Ash.Changeset.force_change_attribute(:invoice_number, invoice_number)
      |> Ash.Changeset.force_change_attribute(:reference, format_number(invoice_number))
    end)
  end

  defp format_number(n), do: String.pad_leading(Integer.to_string(n), 4, "0")
end
