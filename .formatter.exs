[
  plugins: [DoctestFormatter, Styler],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [defbang: 1]
]
