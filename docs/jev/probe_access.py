"""Compare documented Gateway routes without changing account or billing settings."""
from datetime import datetime, timezone
import json
from pathlib import Path
import time
import urllib.error
import urllib.request

from test_jev import load_key

HERE = Path(__file__).resolve().parent
HOST = "https://ai-gateway.vercel.sh"


def main():
    key = load_key(HERE.parents[1] / "jev.txt")
    base = {
        "model": "typesafe-ai/jev",
        "state": "The customer was charged twice for one order.",
        "questions": {"route": {"type": "choice", "instructions": "Choose a support team.",
                                  "criteria": {"billing": "Payments", "shipping": "Deliveries"}}},
    }
    probes = [
        ("credit_balance", "/v1/credits", None),
        ("jev_default", "/v1/evaluate", base),
        ("jev_pinned_1_14", "/v1/evaluate", dict(base, model="typesafe-ai/jev-1.14.0")),
        ("jev_digitalocean", "/v1/evaluate", dict(base, providerOptions={"gateway": {"only": ["digitalocean"]}})),
        ("jev_typesafe_compatible", "/typesafe/v1/systemone", base),
        ("free_credit_control", "/v1/chat/completions", {
            "model": "google/gemini-2.5-flash-lite",
            "messages": [{"role": "user", "content": "Reply OK."}],
            "max_tokens": 4,
        }),
    ]
    results = []
    for name, path, body in probes:
        request = urllib.request.Request(
            HOST + path, data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
            method="POST" if body is not None else "GET",
        )
        result = {"probe": name, "path": path, "request_body": body}
        started = time.perf_counter()
        try:
            response = urllib.request.urlopen(request, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            result["network_error"] = str(error).replace(key, "[REDACTED]")
            results.append(result)
            print(json.dumps({"probe": name, "network_error": result["network_error"]}), flush=True)
            break
        with response:
            result["http_status"] = response.status
            raw = response.read(1_000_000).decode("utf-8", "replace").replace(key, "[REDACTED]")
            result["request_id"] = response.headers.get("x-vercel-id")
        result["elapsed_ms"] = round((time.perf_counter() - started) * 1000, 1)
        try:
            result["response"] = json.loads(raw)
        except ValueError:
            result["response_text"] = raw
        results.append(result)
        payload = result.get("response", {})
        error = payload.get("error", {})
        summary = {"probe": name, "http_status": result["http_status"],
                   "elapsed_ms": result["elapsed_ms"]}
        if name == "credit_balance":
            summary["credits"] = payload
        elif error:
            summary["error"] = error.get("message", error) if isinstance(error, dict) else error
        else:
            summary["model"] = payload.get("model")
            summary["answers"] = payload.get("answers")
            summary["usage"] = payload.get("usage")
            summary["cost"] = payload.get("providerMetadata", {}).get("gateway", {}).get("cost")
        print(json.dumps(summary), flush=True)

    report = {"tested_at_utc": datetime.now(timezone.utc).isoformat(),
              "account_settings_changed": False, "probes": results}
    (HERE / "access-diagnostics.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
