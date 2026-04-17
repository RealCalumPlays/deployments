---
description: When running any console command.
---

- Very carefully plan out potentially long running command runs. Save outputs to files or variables when possible to avoid needing to re-run commands just to grep outputs.
- Note that the testing scripts already save the output of test runs to log files, and the ouput describes where to find those logs. Use the logs for grepping test results instead of re-running tests **unless** there are changes that would affect test results.
- It is *very important* that you follow the above. Wasting time is not only inefficient, but also risks causing problems if you re-run commands that have side effects (e.g. deploying things, modifying infrastructure, etc). Always check the logs first!