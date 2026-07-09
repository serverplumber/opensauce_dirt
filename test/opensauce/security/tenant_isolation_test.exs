# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Security.TenantIsolationTest do
  use OpenSauce.DataCase, async: true

  alias OpenSauce.Test.Factory

  # Each staff_actor() call creates an isolated org. These tests assert that data
  # created in one org is never readable by a member of another org — regardless
  # of whether the multitenancy fragment is misconfigured or a filter is removed.

  test "customers are not visible across organisations" do
    member_a = OpenSauce.DataCase.staff_actor()
    member_b = OpenSauce.DataCase.staff_actor()

    Factory.create_customer!(%{}, member_a)

    visible = Ash.read!(OpenSauce.CRM.Customer, actor: member_b, tenant: member_b.organisation_id)

    assert visible == []
  end

  test "materials are not visible across organisations" do
    member_a = OpenSauce.DataCase.staff_actor()
    member_b = OpenSauce.DataCase.staff_actor()

    Factory.create_material!(%{}, member_a)

    visible =
      Ash.read!(OpenSauce.Inventory.Material, actor: member_b, tenant: member_b.organisation_id)

    assert visible == []
  end

  test "jobs are not visible across organisations" do
    member_a = OpenSauce.DataCase.staff_actor()
    member_b = OpenSauce.DataCase.staff_actor()

    Factory.create_job!(%{}, member_a)

    visible = Ash.read!(OpenSauce.Work.Job, actor: member_b, tenant: member_b.organisation_id)

    assert visible == []
  end
end
