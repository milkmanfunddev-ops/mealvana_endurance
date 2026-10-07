# 01-008 · Body composition defaults to Imperial (ft/in, lb) for a device in en_GB

- kind: idea
- status: wontfix
- ticket: 01
- run: w1-20261007T1103Z
- screen: Basic body composition
- decision: 

**Steps.**
1. With `AppleLocale en_GB`, reach onboarding's "Basic body composition" page. Idea: default the unit toggle from the device locale (Metric for en_GB and most non-US locales), keeping the toggle.

**Expected.**
A UK device starts on Metric (cm, kg); switching stays one tap.

**Actual.**
Unit preferences start on Imperial (5 ft 8 in, 150 lb) whatever the locale. Switching to Metric worked (173 cm, 68 kg, then set to 72 kg).

**Evidence.**
- runs/01/43-C-bodycomp.png
- runs/01/44-C-metric.png

**Decision quote.**
> 

**Triage.**
Lee: the unit default is Xuan's onboarding call
