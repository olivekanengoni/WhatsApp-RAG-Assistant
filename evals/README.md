# WhatsApp RAG Assistant

Answers questions over a business's own documents on WhatsApp. Cites its sources, refuses when the answer isn't in the documents, and ships with an eval harness that measures what each retrieval stage adds.

```
WhatsApp -> FastAPI webhook -> query rewrite (Haiku) -> hybrid retrieval (pgvector + Postgres FTS, RRF)
         -> rerank (Voyage) -> grounded answer with [n] citations (Claude) -> WhatsApp
```

## Quick start

```bash
cp .env.example .env          # add ANTHROPIC_API_KEY and VOYAGE_API_KEY at minimum
docker compose up -d --build
docker compose exec app python -m app.ingest docs     # ingests docs/sample_tenant_faq.md
curl -s localhost:8000/ask -H "X-Admin-Key: change-me" -H "Content-Type: application/json" \
  -d '{"question":"How much is the deposit for a furnished flat?"}'
```
Admin page (upload docs, try questions): http://localhost:8000/admin

## Connect WhatsApp
1. developers.facebook.com -> create an app (type Business) -> add the **WhatsApp** product.
2. Copy the **temporary access token** and **Phone number ID** into `.env` (`WA_ACCESS_TOKEN`, `WA_PHONE_NUMBER_ID`). Copy the **App Secret** (App settings -> Basic) into `WA_APP_SECRET`.
3. Expose your server: `cloudflared tunnel --url http://localhost:8000` (or ngrok).
4. In WhatsApp -> Configuration, set the callback URL to `https://<tunnel>/webhook` and the verify token to your `WA_VERIFY_TOKEN`. Subscribe to the **messages** field.
5. Add your own number as a test recipient and message the test number. Send `reset` to clear conversation memory.

For production use a permanent System User token, not the temporary one.

## Evals
Replace `docs/` and `evals/dataset.jsonl` with your niche's documents and 50-100 hand-written questions (include ~20% unanswerable ones).

```bash
docker compose exec app python -m evals.run_evals              # full run
docker compose exec app python -m evals.run_evals --no-answers # retrieval only, no LLM cost
```
Results are printed and saved to `evals/results.md`. Paste them below.

## Results
| Method | Hit@5 | MRR |
|---|---|---|
| vector | | |
| bm25 | | |
| hybrid (RRF) | | |
| hybrid + rerank | | |

## Failure analysis
Where it still fails and why (chunking splits a table, abbreviations, multi-hop questions, Arabic, refusal threshold too strict/loose). Be specific and link failing questions.

## Design notes
- **Chunking:** by heading path first, then by size (~1800 chars) with one-paragraph overlap. Each chunk is embedded with its doc name and heading path prepended.
- **Hybrid search:** Postgres full-text (`ts_rank_cd`, BM25-like, not identical) + cosine similarity, merged with reciprocal rank fusion (k=60).
- **Refusal:** two layers: reranker score below `MIN_RERANK_SCORE`, and the model answering `NO_ANSWER`. Tune the threshold with the evals.
- **Safety:** webhook signature verification, idempotent message handling, source text treated as data (prompt-injection guard).
- **Cost/latency:** every query logs stage timings and token counts to `query_log`.
