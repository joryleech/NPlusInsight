# Releasing NPlusInsight

## First release

1. Create or sign in to your account at https://rubygems.org.
2. Enable MFA for the account.
3. Confirm that `n_plus_insight` is still available:

   ```sh
   gem search --remote --exact n_plus_insight
   ```

   No output means there is no published gem with that exact name.

4. Authenticate without putting an API key in the repository:

   ```sh
   gem signin
   ```

5. Run the tests and build the package:

   ```sh
   bundle install
   bundle exec rake test
   bundle exec rake build
   ```

6. Publish the built package:

   ```sh
   gem push pkg/n_plus_insight-0.1.0.gem
   ```

7. Verify the release:

   ```sh
   gem info n_plus_insight --remote
   ```

## Later releases

Update `NPlusInsight::VERSION` in `lib/n_plus_insight/version.rb`, add the
release notes to `CHANGELOG.md`, rerun the tests, build, and push the new
version. RubyGems does not allow replacing an existing version.

Never commit `.gem/credentials`, an API key, or an OTP recovery code.
