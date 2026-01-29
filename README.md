# Bukowski

Bukowski is a lambda-calculus interpreter written in Ruby. It converts labmda-calculus to SKI combinators and then executes the SKI combinators.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

Start the REPL:

```bash
./bin/bukowski
```

Or execute a file:

```bash
./bin/bukowski myfile.bk
```

### Examples

Bukowski uses prefix notation. Operators come before their arguments.

```
λ> + 2 3
=> 5

λ> * 4 5
=> 20
```

Lambda abstractions use `\` (or `λ`) and `.` to separate the parameter from the body:

```
λ> (\x.+ x 1) 5
=> 6

λ> (\x.\y.+ x y) 3 4
=> 7
```

Booleans are Church-encoded. Comparisons return Church booleans:

```
λ> = 2 2
=> true

λ> > 5 3
=> true

λ> = 1 2
=> false
```

Use `if` with Church booleans:

```
λ> if (= 1 1) 10 20
=> 10

λ> if (= 1 2) 10 20
=> 20
```

Strings support concatenation, comparison, and `length`:

```
λ> + "hello" " world"
=> "hello world"

λ> = "abc" "abc"
=> true

λ> length "hello"
=> 5
```

`let` bindings desugar to lambda application:

```
λ> let x = 5 in + x 3
=> 8
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/philcrissman/bukowski. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/philcrissman/bukowski/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Bukowski project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/bukowski/blob/main/CODE_OF_CONDUCT.md).
