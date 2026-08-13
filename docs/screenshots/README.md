# Screenshots

A visual record of this project working end to end in Azure - resource
provisioning, Synapse workspace/pool setup, and the full SQL debugging
and analysis session.

## Resource provisioning

| File | Shows |
|---|---|
| `resource-groups-1.jpg` - `resource-groups-3.jpg` | Resource group `rg-synapse-nyc-taxi`, storage account, and provisioned resources in the Azure Portal |
| `storage-center-1.jpg`, `storage-center-2.jpg` | Storage account overview and the `raw` container with ingested Parquet data |

## Synapse Studio

| File | Shows |
|---|---|

| `synapse.jpg` - `synapse_________________.jpg` | The full SQL debugging and analysis session in Synapse Studio: external data source/credential setup, the SQL scoped credential and master key fixes, the external table schema corrections (VARCHAR vs INT), the 8.7M-row count confirmation, all six analytical queries (daily trip volume, fare/distance by hour, tip % by payment type, busiest pickup zones, data quality flags, and the CETAS write-back), and the final verified `DailyTripSummary` output |

---

These screenshots include the real debugging trail (failed queries, error
messages, iterative schema fixes) alongside the final working results -
that's intentional, matching the troubleshooting notes in the main
[README](../../README.md#troubleshooting-notes-from-actually-building-this).
The path from "no datasets were found" to 8.7 million real rows queried
successfully is the actual story of this project, not just the end state.
