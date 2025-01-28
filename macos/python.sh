#!/bin/sh

curl -LsSf https://astral.sh/uv/install.sh | sh

# Install 3.10 3.11 3.12 and set 3.12 as ddefault with uv
uv python install 3.10 3.11 3.12
