# 0010: Inference work aimed at serving at scale

Status: accepted

## Context

[0006](0006-ai-infrastructure.md) gave inference a single phase after the
GPU node. Inference platform work comes down to the same handful of
problems wherever it's done:

- routing requests across many accelerators
- autoscaling capacity to match demand
- releasing new models safely
- running more than one accelerator type behind one service
- inference features such as prompt caching and structured output
- tuning performance from production metrics
- multi-region deployment and geographic routing

Most of these can be practised at small scale, and several need no GPU at
all: `llm-d-inference-sim` imitates vLLM's API and metrics on a CPU. One
phase can't cover them, and waiting for the GPU node delays the routing
work that doesn't need it.

## Decision

Inference becomes six phases, each run as an experiment in `experiments/`
with a hypothesis, a harness and the raw results:

1. **Routing on simulators**, straight after Argo CD. An InferencePool of
   simulated vLLM replicas behind the Gateway API Inference Extension.
   Compare round robin, least queue, prefix-cache-aware routing and a
   scoring policy of my own, written as an endpoint-picker plugin, under
   bursty replayed traffic.
2. **Serving on the GPU**, after the GPU node joins:
   - vLLM on the RTX 5070, repeating the routing comparison on real hardware
   - prefix caching on and off, using the document flow's long shared
     prompts
   - structured output against a JSON schema for document extraction:
     accuracy gained against throughput lost
   - batching tuned from metrics (concurrent sequences, chunked prefill) and
     the quantisation formats the card supports
   - a mixed pool: the GPU plus simulated replicas tuned to behave like a
     slower second accelerator type, routed by capacity rather than replica
     count
   - the document flow moves onto it
3. **Autoscaling and cold starts.** Scale model servers on queue depth with
   KEDA, including to zero. The Go controller pre-caches model weights on
   nodes. Measure time from a burst to serving it, requests within the
   latency target during the burst, and idle accelerator time.
4. **Model rollouts.** A release pipeline for a new model version: canary
   by weighted routing, automatic gates on latency and on a small
   evaluation set (document extraction accuracy), and automatic rollback.
   Measure rollback time and how many requests the bad version served.
5. **Multi-zone routing.** Split the nodes into two zones, add latency
   between them, route by locality with failover, and drill the loss of a
   zone under load. Measure failover time and errors during it.
6. **Scheduling** (DRA, Kueue, JobSet) moves after these. It's batch- and
   training-shaped, and less central to serving.

Every experiment reports the same core metrics where they apply:

- time to first token and inter-token latency, p50 and p99
- throughput, and goodput (requests within the latency target)
- prefix-cache hit rate and accelerator utilisation
- time to scale and time to roll back
- cost per million tokens, from measured power draw

Harnesses and analysis are in Python: a load generator that replays public
LLM request traces, and the scripts that turn raw results into the numbers
in each write-up.

## Alternatives

- **Keep one inference phase after the GPU node**: delays the routing work
  by months, and covers routing only.
- **Rent cloud GPUs for all of it**: real hardware, but long experiments get
  expensive and the bare-metal layers drop out.

## Consequences

- The roadmap gets longer, and scheduling moves later.
- Simulators test routing and scaling logic, not real performance.
  Write-ups say which results are simulated, and the GPU phase repeats the
  key routing comparison on real hardware.
- Python becomes the lab's main language for harnesses. Go stays for the
  weight-cache controller and the routing plugin.
- Scale stays the honest gap: one GPU, not thousands.
