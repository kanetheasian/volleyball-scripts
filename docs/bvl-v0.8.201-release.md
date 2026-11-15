# BVL Assist v0.8.201

Fix an incorrect spec-related guard in Receive/grounded Set jump cancellation, sprint during those actions and Auto Receive. Spec_NoAction is used by SpecCooldownShared to track action cooldown usage; it is not the native input-disable state. These controls now follow the real DisableInputs and state-machine locks, physical readiness, Jump.CanEnter and native sprint stamina/cooldown predicates. The flag is read-only and is not cleared or changed by this fix.

The reported trigger was a teammate activating Osabu (Osamu) while the local player uses Atsumu. The connected client confirmed these specs and the enabled controls, but the actual failing activation was not captured. This fixes the identified incorrect guard; full Osamu-specific live reproduction remains pending.

Full regression passed, including 647 runtime checks. Incorrect tests treating the cooldown flag as a native lock were replaced with explicit Receive Jump and sprint regression cases for a true Spec_NoAction flag. Real input/state restrictions remain tested. O0/O1 compilation passed. The live reload preserved configuration, with ReceiveJumpCancel=true, ReceiveSprintReady=true and no reported runtime errors.

Bundle: 900679 bytes. SHA-256: `453592c5b80b09da930c52cfc467fcc9142b191c759435a7b9f553dde50e6425`.
