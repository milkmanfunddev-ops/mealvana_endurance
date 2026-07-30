#### Compression: effect vs the noise floor (n=3 per cell)

| Image | Haiku 1000px | Haiku full | Δ | noise | verdict | Sonnet 1000px | Sonnet full | Δ | noise | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `img-01` | 189 | 189 | 0% | 0% | noise | 293 | 156 | 47% | 31% | noise |
| `img-02` | 355 | 378 | 6% | 6% | noise | 317 | 377 | 16% | 5% | **SIGNAL** |
| `img-03` | 563 | 587 | 4% | 11% | noise | 620 | 640 | 3% | 2% | noise |
| `img-04` | 520 | 520 | 0% | 0% | noise | 520 | 520 | 0% | 0% | noise |
| `img-05` | 393 | 320 | 19% | 5% | **SIGNAL** | 283 | 283 | 0% | 2% | noise |
| `img-06` | 141 | 110 | 22% | 21% | noise | 130 | 186 | 30% | 11% | **SIGNAL** |
| `img-07` | 393 | 353 | 10% | 25% | noise | 371 | 381 | 2% | 10% | noise |
| `img-08` | 210 | 210 | 0% | 0% | noise | 210 | 210 | 0% | 0% | noise |
| `img-09` | 539 | 428 | 21% | 27% | noise | 659 | 680 | 3% | 3% | noise |
| `img-10` | 645 | 622 | 4% | 5% | noise | 673 | 697 | 3% | 6% | noise |
| `img-11` | 578 | 722 | 20% | 8% | **SIGNAL** | 715 | 714 | 0% | 5% | noise |

**Images with a compression effect above noise: Haiku 2/11 · Sonnet 2/11**

#### Run-to-run consistency (same model, same image, 3 runs)

| Model | Median CV | Mean CV | Worst CV | Images where all 3 runs identical |
| --- | --- | --- | --- | --- |
| Haiku | 4.9% | 6.9% | 26.7% | 6/22 cells |
| Sonnet | 1.9% | 5.3% | 30.8% | 5/22 cells |
