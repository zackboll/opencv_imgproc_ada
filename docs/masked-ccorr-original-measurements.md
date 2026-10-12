# Original exact-gate failure evidence (before continuation)

The original 34 fixtures/882 samples per version were not accepted under the
zero-tolerance landmark criterion. The following original 4.1.0 diagnostics
are retained verbatim in value, independent of the revised test policy:

| Fixture | Location | Native Float32 | Exact integer oracle | Original limit |
|---|---|---|---|---|
| landmark | (0,0) | -7.5791227406498546e-14 | 0 | 0 |
| excluded-corruption | (3,4) | -1.3263463949104298e-13 | 0 | 0 |
| excluded-corruption | (5,5) | -5.711511450422202e-13 | 0 | 0 |
| excluded-corruption | (9,5) | 5.3676155317358698e-13 | 0 | 0 |

Landmark, brightness, and excluded-corruption maps had residuals at zero
oracle windows. Pairwise version comparisons had zero absolute/relative/ULP
differences and zero maximum-location changes; newer masked controls also
matched exactly. This did not make the original oracle gate pass.

Full original maps and error logs are preserved locally, without overwriting,
under `/tmp/imgproc051-masked-ccorr/tests/bin/masked-ccorr-original/`.
All original fixtures remain in the reusable corpus. The `CASE` exact flag
continues to identify the original zero-tolerance designation; it is historical
metadata, not the revised acceptance limit. No production score was repaired.