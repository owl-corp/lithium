# Lithium

Lithium is a mail authentication process implemented by Owl Corp.


## Goals

- Implementing modern email validation and authentication standards
  - SPF, ARC, DKIM, DMARC, and associated bells and whistles
- Abstracting away the milter protocol
- Integrating with Postfix
- World domination


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `lithium` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lithium, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/lithium>.


## Development

To develop locally, you can use GNU Guix to drop you into a shell with the
required dependencies to build and test Lithium:

```sh
$ guix shell -m manifest.scm
```


## License

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.
A copy of the license can be found in [this directory](./LICENSE).
