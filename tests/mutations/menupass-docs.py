# Mutations for the docs sweep: tests/validate.py's README page check and its
# listing check.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the check that objects.

V = "validate.py"

mutate("README.md",
       "\n### Quiet times\n",
       "\n### Quiet\n",
       "menupass-docs: the README loses a page's part",
       expect="README.md has no '### <page>' part for", script=V)

mutate(".github/curseforge-description.md",
       "*Hide the prompt in a fight*",
       "*Hide the prompt in combat*",
       "menupass-docs: a listing names the old label",
       expect="which the menu pass renamed", script=V)
