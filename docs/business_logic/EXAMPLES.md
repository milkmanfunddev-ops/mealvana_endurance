# Usage Examples

This document provides usage examples for the run fueling nutrition planning tool.

## Basic Usage

```bash
# Metric units example
python3 run_fueling.py --age 30 --gender female --weight 60 --height 170 --pace "8:00" --distance 10 --time-before-run-min 120
```

## Imperial Units Example

```bash
# Imperial units with different parameters
python3 run_fueling.py --age 25 --gender male --weight 150 --weight-unit lb --height 70 --height-unit in --pace "7:30" --distance 6.2 --distance-unit mi --time-before-run-min 90
```

## Testing Compilation

```bash
# Verify syntax (note: requires Python 3.10+ for union types)
python3 -m py_compile run_fueling.py
```

## Parameter Explanation

- `--age`: Athlete's age in years
- `--gender`: male or female (affects metabolic calculations)
- `--weight`: Body weight (default: kg, use --weight-unit for lb)
- `--height`: Height (default: cm, use --height-unit for inches)
- `--pace`: Running pace (format: "MM:SS" per mile/km)
- `--distance`: Run distance (default: km, use --distance-unit for miles)
- `--time-before-run-min`: Minutes between eating and running start