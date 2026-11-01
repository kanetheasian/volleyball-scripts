# BVL v0.8.61: sideline back Sets and stamina refill isolation

For normal receives outside a sideline, Auto Set now prefers a validated back Set. It uses the current ball or predicted contact against the authored court axes, tries back before front, and falls back to front when back is unavailable. Ordinary in-bounds mixed-set choices and held Dump behavior remain separate. The sideline preference is independent of random-mix streaks. A late grounded failure can change to a validated front Set; an airborne commitment is not flipped through an impossible half-turn.

Local stamina refill now runs in protected calls before simulation, ahead of the shared heartbeat update, and before automated native sprint requests. It follows the current native stamina value object, respects its toggle and native no-action restriction, and records before/after/maximum/status diagnostics. The earlier placement late in the shared update could skip refill after an unrelated error. This isolation change does not establish the cause of the reported live stamina drain or prove that native/server stamina limits are bypassed.

Validation: 1,838 main/component assertions and full-bundle Luau compilation at optimization levels 0 and 1 passed. New tests cover sideline back preference, front fallback, predicted sideline contacts, rotated axes, in-bounds mixing, pre-simulation stamina refill, toggle-off behavior, unrelated update failure and replaced native stamina objects. The client disconnected before this version could be loaded or tested live. Publication was explicitly requested with live verification still pending.

Bundle: 508,613 bytes. SHA-256: 64F73BA667AAB92212C09ECEA72BACCAC8F4FBCA9B1558417B4E587B4FDF3987.
