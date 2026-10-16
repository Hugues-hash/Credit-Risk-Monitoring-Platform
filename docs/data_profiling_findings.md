# Data Profiling Findings - Lending Club Staging Dataset

## 1. Identifiers (`id`, `member_id`)
* **Total Records Staged**: 2,260,701
* **`id` Integrity**: 100% unique (0 duplicate values). Verified natural key for loan-level grain.
* **`member_id` Integrity**: 100% NULL (0 non-null records). Column removed by data provider for PII privacy; exclude from Dim/Fact schema.