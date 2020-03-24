CHANGELOG_FILE = "CHANGELOG.md"
GITHUB_REPO = "https://github.com/doorkeeper-gem/doorkeeper"

def changelog_changed?
  git.modified_files.include?(CHANGELOG_FILE) || git.added_files.include?(CHANGELOG_FILE)
end

def changelog_entry_example
  pr_number = github.pr_json["number"]
  pr_title = github.pr_title
                   .sub(/[?.!,;]?$/, "")
                   .capitalize

  "- [##{pr_number}] #{pr_title}."
end

# --------------------------------------------------------------------------------------------------------------------
# Has any changes happened inside the actual library code?
# --------------------------------------------------------------------------------------------------------------------
has_app_changes = !git.modified_files.grep(/lib|app/).empty?
has_spec_changes = !git.modified_files.grep(/spec/).empty?

# --------------------------------------------------------------------------------------------------------------------
# You've made changes to lib, but didn't write any tests?
# --------------------------------------------------------------------------------------------------------------------
if has_app_changes && !has_spec_changes
  warn("There're library changes, but not tests. That's OK as long as you're refactoring existing code.", sticky: false)
end

# --------------------------------------------------------------------------------------------------------------------
# You've made changes to specs, but no library code has changed?
# --------------------------------------------------------------------------------------------------------------------
if !has_app_changes && has_spec_changes
  message("We really appreciate pull requests that demonstrate issues, even without a fix. That said, the next step is to try and fix the failing tests!", sticky: false)
end

# Mainly to encourage writing up some reasoning about the PR, rather than
# just leaving a title
if github.pr_body.length < 10
  fail "Please provide a summary in the Pull Request description"
end

# --------------------------------------------------------------------------------------------------------------------
# Have you updated CHANGELOG.md?
# --------------------------------------------------------------------------------------------------------------------
# Add a CHANGELOG entry for app changes
if has_app_changes && !changelog_changed?
  markdown <<-MARKDOWN
Here's an example of a #{CHANGELOG_FILE} entry:
```markdown
#{changelog_entry_example}
```
  MARKDOWN

  warn(
    "Please include a changelog entry. \nYou can find it at [#{CHANGELOG_FILE}](#{GITHUB_REPO}/blob/master/#{CHANGELOG_FILE})." +
      "You can skip this warning only if you made some typo fix or other small changes that didn't affect the API."
  )
end

if git.commits.any? { |commit| commit.message =~ /^Merge branch '#{github.branch_for_base}'/ }
  warn("Please rebase to get rid of the merge commits in this PR")
end

if git.commits.length > 1
  warn("Please squash all your commits to a single one")
end
