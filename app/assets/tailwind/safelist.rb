# frozen_string_literal: true

# Tailwind CSS Safelist
# This file exists solely for Tailwind's scanner to find dynamically-generated class names.
# These classes are constructed at runtime in helpers/views but need to be in the CSS bundle.

%w[
  badge-neutral badge-warning badge-success badge-error badge-info
  text-neutral text-warning text-success text-error text-info
]
