# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.CRM.EngagementPolicyTest do
  use OpenSauce.DataCase, async: true

  # Engagements require manager+ to create, update, or destroy.
  # These tests use Ash.can?/3 to check the policy directly without model fields,
  # so they only need to change if the intended authorization rule changes.

  test "staff cannot create engagements" do
    member = OpenSauce.DataCase.staff_actor()
    refute Ash.can?({OpenSauce.CRM.Engagement, :create}, member, tenant: member.organisation_id)
  end

  test "manager can create engagements" do
    member = OpenSauce.DataCase.admin_actor()
    assert Ash.can?({OpenSauce.CRM.Engagement, :create}, member, tenant: member.organisation_id)
  end

  test "staff can read engagements" do
    member = OpenSauce.DataCase.staff_actor()
    assert Ash.can?({OpenSauce.CRM.Engagement, :read}, member, tenant: member.organisation_id)
  end
end
