## What changed and why

<!-- One or two sentences. Link the issue or incident if there is one. -->

## How it was checked

- [ ] `terraform fmt -check -recursive` and `terraform validate` pass for each changed module
- [ ] New inputs have a description, a type and a default that keeps existing environments unchanged
- [ ] The README lists new inputs or behaviour

## Risk and rollback

<!-- What could break, and how to undo it (usually: revert this PR). -->
