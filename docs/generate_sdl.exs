# Copyright (c) 2026 serverplumber. Licensed under the Elastic License 2.0.
# SPDX-License-Identifier: Elastic-2.0

sdl = Absinthe.Schema.to_sdl(OpenSauceWeb.Schema)

File.write!("docs/public/schema.graphql", sdl)
IO.puts("Generated docs/public/schema.graphql")
