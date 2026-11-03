# v0.8.132

Fix local stamina refill stopping after spec activation. The old refill incorrectly treated Spec_NoAction, a spec cooldown usage flag, as a reason to stop replenishing stamina. Refill now continues while the stamina toggle is enabled and reads the active movement container each time. Missing stamina or invalid maximum values still defer refill; turning the toggle off still stops it. No spec activation, cooldown or server attribute is changed.

Live Kageyama capture reproduced the problem on v131: the toggle remained enabled, Spec_NoAction became true, refill stopped and stamina fell from 10 to 5. Movement/stamina object identities remained unchanged. After loading v132 with settings preserved, passive observation confirmed repeated 9-to-10 refills with Spec_NoAction still true and no runtime errors. This verifies local client refill for the observed spec state, not all spec abilities or server-side stamina handling.

Validation: 4,654 local assertions passed, including six new spec/replacement-resource tests; Luau O0/O1 compilation passed. Bundle SHA256: 645DD371E36E066725313238D624F14BC19DC77B50A52E8603EF2C1FD5AEA982.
