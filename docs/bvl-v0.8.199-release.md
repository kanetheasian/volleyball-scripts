# BVL Assist v0.8.199

Fix excessive Unsure on clearly out projected landings. Pending spike spin no longer blocks an Out projection more than 1.5 studs beyond the ball-adjusted boundary. Only movement toward the boundary increases the adaptive margin; movement along the line or farther out does not. Out resolves immediately when outside that margin. In still requires brief confirmation. A rebound or missing court/landing clears prior confidence. These remain predicted calls and later spin or player contact can change the result.

Full regression passed, including 84 forecast checks with four added cases for provisional far-out spikes, along-line movement, farther-out corrections and inward corrections. O0/O1 compilation passed. Live validation is pending while the client is disconnected. Rerun the BVL loader to update.

Bundle: 900472 bytes. SHA-256: `1b9736072c89d5a2f7ae8d8600f79b3e41d3c16575b7195a4c2e8c70e733af3d`.
