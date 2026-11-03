# BVL Assist v0.8.130: saved-profile compatibility fix

Versions v0.8.125-v0.8.129 expanded the spiker aim-line length range from 2-20 to 80-300 studs. Previously saved profiles contained the older length (normally 8). Strict import validation rejected the library and its backup, leaving the dropdown empty even though the files were preserved.

Profile import now migrates only the known old 2-20 range to the new visual default before validation. Profile names, all other settings, selected profile and autoload preference remain intact. Reading the library does not rewrite either file. New explicit lengths and invalid-value checks remain unchanged.

Verified recovery on the connected account: both saved profiles appeared again, the previously selected profile autoloaded, the read error cleared, and the primary and backup files matched their pre-fix bytes exactly. Validation: 4407 assertions, 52 preview-runtime checks, and O0/O1 compilation.

Rerun the existing loader to recover profiles hidden by this compatibility bug. This fix does not restore independently deleted files or executor storage cleared outside the script. v0.8.129 landing-line and v0.8.124 gameplay limitations remain.
