# Pending changelog entries

Instead of editing `CHANGELOG.md` directly (which conflicts whenever two
pull requests race for the same line), add your entry as a new file in this
directory:

1. Create `changelogs/<pr-number>-<short-slug>.md`, e.g.
   `changelogs/1234-fix-token-revocation.md`. If you don't know the PR
   number yet, a descriptive slug alone is fine — the name only affects
   ordering.
2. Write the entry exactly as it should appear in the `## main` section of
   `CHANGELOG.md`, usually a single bullet:

   ```markdown
   - [#1234] Fix: something user-visible worth mentioning.
   ```

   Multi-line entries with sub-bullets are fine too — the file content is
   inserted verbatim.

After your pull request is merged, the "Changelog aggregation" workflow
(`.github/workflows/changelog_aggregation.yml`) opens an automatic pull
request that moves every pending entry into `CHANGELOG.md` and deletes the
collected files. You never need to touch `CHANGELOG.md` yourself.

This `README.md` is the only file here that is never collected.
