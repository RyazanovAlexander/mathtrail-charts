#!/bin/bash
set -e

# Initialize chezmoi with core repo to generate ~/.env.shared
chezmoi init --apply --force https://github.com/MathTrail/core.git
