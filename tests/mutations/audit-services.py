mutate(
    "tools/audit_services.py",
    '    return findings\n\n\ndef dump(flavour, class_name):\n',
    '    return []\n\n\ndef dump(flavour, class_name):\n',
    "audit-services: a service can disappear from the expected matrix",
    expect="a removed service did not fail the audit",
    script="validate.py",
)
