# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

defmodule OpenSauce.Work.JobEvent.TagOnly do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :atom do
      allow_nil? false
      public? true
    end
  end
end
