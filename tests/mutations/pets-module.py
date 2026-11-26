mutate(
    "Modules/Pets/Manners_Pets.toc",
    "## DefaultState: enabled",
    "## DefaultState: disabled",
    "pets-module: Pets ships enabled",
    expect="pets-module: default enabled and inert outside the hunter",
    script="runscenarios.py",
)
