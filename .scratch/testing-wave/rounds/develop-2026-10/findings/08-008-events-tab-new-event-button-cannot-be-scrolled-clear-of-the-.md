# 08-008 · Events tab: New Event button cannot be scrolled clear of the floating tab bar

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: My Events (Events tab)
- decision: 

**Steps.**
1. Signed in as test@test.com (1 upcoming + 4 past events). Open the Events tab.
2. Drag the list up as far as it goes.

**Expected.**
The New Event button scrolls fully above the floating tab bar and can be tapped.

**Actual.**
At the end of the scroll the orange New Event button still sits under the tab bar (only its top edge shows above the Events pill); its centre (y≈806) is the Events tab's. The list's bottom padding (AppSpacing.xxxl, from code) is smaller than the floating bar. Not tapped (read-only ticket).

**Evidence.**
- runs/08/b05-after-fast-tab-switch.png
- runs/08/b06-events-scrolled.png after scrolling to the end

**Decision quote.**
> 

**Triage.**
