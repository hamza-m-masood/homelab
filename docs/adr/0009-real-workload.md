# 0009: A real workload: document processing for a car import business

Status: accepted

## Context

Everything the lab runs so far is synthetic. A family business imports used
cars from Japan and sells them in Ireland, and most of its paperwork is
still on paper: Japanese auction sheets and export certificates, invoices
and shipping documents, then customs and VAT, VRT and the NCT on the Irish
side, and the sales paperwork after that.

Camunda 8 can orchestrate that work with agentic BPMN flows and document
extraction, and it's the product I know best. A real user also gives the AI
infrastructure phases ([0006](0006-ai-infrastructure.md)) real traffic: the
GPU node serves the models that read the documents, Ceph stores them, and
the routing experiments see real requests.

The lab's original brief ruled out "just another Camunda install". Here
Camunda is the application, not the point: the interesting parts are
document AI on my own hardware, agents with guardrails, and running it on
bare metal.

## Decision

- Camunda 8 Self-Managed runs in the lab, deployed by Argo CD from the
  official Helm chart, on Ceph block storage.
- One flow gets built end to end before anything else:
  1. Photos or scans of one car's documents start a process instance.
  2. Extraction identifies each document, pulls out the chassis number,
     mileage, first registration date and grade, and translates the
     Japanese fields.
  3. An AI agent cross-checks the documents (chassis numbers match, mileage
     agrees between auction sheet and export certificate) and flags
     mismatches.
  4. Anything uncertain becomes a user task. Nothing is final without a
     person.
  5. The result is one file per car, plus timer reminders for customs and
     VAT, VRT and the NCT.
- Paper stays the source of truth until the system has proven itself. It's
  an assistant the business can work without.
- Models: a cloud API on redacted or made-up documents while building. Real
  customer documents only once inference runs on the GPU node.
- The platform side (the Camunda deployment) lives in this repo under
  `kubernetes/workloads/`. Process models and workers live in their own
  repository, with made-up sample documents only.
- It gets written up as its own blog series after the OAuth series. The
  homelab posts stay a separate track.

## Open questions

All four need an answer before real documents go through it.

- **Licensing**: as I understand it, Camunda 8 Self-Managed is free for
  non-production use and needs a licence for production. A real business is
  production. To ask at work.
- **Lab or production**: once the business relies on it, failure drills
  can't happen at will. Either it stays an assistant the business can work
  without, or its workflows get production treatment: off-site backups,
  alerting, and drills scheduled around it.
- **Data protection**: the documents hold customers' personal data (GDPR).
  Data stays in the lab, access goes through OIDC, and no real document goes
  into a public repo or post. What gets shared publicly about the business
  is agreed with it first.
- **Writing about Camunda as an employee**: check the policy on public
  content about the product.

## Alternatives

- **Camunda SaaS**: production-grade with nothing to run, and possibly the
  right home if this outgrows the lab. It skips the platform work this lab
  exists for, and customer documents leave the house.
- **A general automation tool** (n8n, Zapier): quick for simple automations,
  weaker at long-running processes with human tasks and an audit trail, and
  not where my expertise is.
- **Keep the lab synthetic**: no risk to anyone, but no real user and
  nothing to measure beyond benchmarks.

## Consequences

- The roadmap gains a Camunda phase right after storage, before the GPU
  node, so the first flow can run on a cloud model while the GPU node waits.
- The storage phase's Zeebe node-loss tests run against the same Camunda
  deployment the business will use, before it holds real data.
- Results get measured from the start: documents processed, extraction
  accuracy per field, hours saved per week, cost per document on the GPU
  node vs a cloud API.
