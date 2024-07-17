# Senzing Elixir NIF

[![Main Branch](https://github.com/sustema-ag/senzing-elixir/actions/workflows/branch_main.yml/badge.svg?branch=main)](https://github.com/sustema-ag/senzing-elixir/actions/workflows/branch_main.yml)
[![Module Version](https://img.shields.io/hexpm/v/senzing.svg)](https://hex.pm/packages/senzing)
[![Total Download](https://img.shields.io/hexpm/dt/senzing.svg)](https://hex.pm/packages/senzing)
[![License](https://img.shields.io/hexpm/l/senzing.svg)](https://github.com/sustema-ag/senzing-elixir/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/sustema-ag/senzing-elixir.svg)](https://github.com/sustema-ag/senzing-elixir/commits/master)
[![Coverage Status](https://coveralls.io/repos/github/sustema-ag/senzing-elixir/badge.svg?branch=main)](https://coveralls.io/github/sustema-ag/senzing-elixir?branch=main)

<!-- MDOC -->

Elixir NIF for [Senzing©](https://senzing.com/) Entity Matching.

<br clear="left"/>

<picture style="margin-right: 15px; float: left;">
  <source
    media="(prefers-color-scheme: dark)"
    srcset="assets/senzing-logo-dark.png"
    width="170px"
    align="left"
  />
  <source
    media="(prefers-color-scheme: light)"
    srcset="assets/senzing-logo-light.png"
    width="170px"
    align="left"
  />
  <img
    src="assets/senzing-logo-light.png"
    alt="Senzing Logo"
    width="170px"
    align="left"
  />
</picture>

This package is providing an interface for the [Senzing©](https://senzing.com/)
C SDK.

<br clear="left"/>

<picture style="margin-right: 15px; float: left;">
  <source
    media="(prefers-color-scheme: dark)"
    srcset="assets/sustema-logo-dark.svg"
    width="170px"
    align="left"
  />
  <source
    media="(prefers-color-scheme: light)"
    srcset="assets/sustema-logo-light.svg"
    width="170px"
    align="left"
  />
  <img
    src="assets/sustema-logo-light.svg"
    alt="Sustema Logo"
    width="170px"
    align="left"
  />
</picture>

This library was developed for free by [Sustema AG](https://sustema.io).

<br clear="left"/>

## Installation

To be able to run this package, Senzing has to be installed by following the
Linux setup guide: <https://docs.senzing.com/quickstart/quickstart_api/>

The path used in
[`G2CreateProject`](https://docs.senzing.com/quickstart/quickstart_api/#create-a-senzing-project)
has to be set as an environment variable `SENZING_ROOT`.

The package can be installed by adding `senzing` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:senzing, "~> 0.1.0"}
  ]
end
```

## Docs

* NIF: <https://hexdocs.pm/senzing>
* Senzing Developer Docs: <https://senzing.com/developer/>
