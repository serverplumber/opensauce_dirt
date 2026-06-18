# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

ExUnit.start(exclude: [:e2e])
Ecto.Adapters.SQL.Sandbox.mode(OpenSauce.Repo, :manual)
