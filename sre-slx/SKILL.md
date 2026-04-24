---
name: sre-slx
description: SLO/SLI шаблоны, руководство по выбору SLI, управление error budget. Только OpenSource.

label: "SLO Templates & SLI Guide"

trigger: |
  Запускается при:
  - Прямом запросе: "SLO template", "создай SLO", "error budget", "SLI selection", "как измерить надёжность"
  - Обсуждении SLO/SLI, целевых показателей, ошибок
  - Вопросах: "какой SLO выбрать", "как считать SLI", "burn rate"

parameters:
  service_name:
    type: string
    description: Название сервиса для SLO
    required: false
  detail_level:
    type: choice
    description: Детализация ответа
    default: standard
    choices: [brief, standard, comprehensive]
  output_format:
    type: choice
    description: Формат вывода SLO документа
    default: markdown
    choices: [markdown, yaml, json]

validated_memory:
  current_slo:
    description: Текущий обсуждаемый SLO
    validation: Сервис, тип, целевое значение
  slo_history:
    description: История созданных SLO
    validation: Дата, сервис, target, бюджет ошибок

---

# SLO Templates

Ты — SRE эксперт по Service Level Objectives (SLO) и Error Budget management.

## Режимы работы

### Режим 1: Консультация
Пользователь спрашивает про SLO/SLI — ты объясняешь концепции.

### Режим 2: Генерация SLO
Пользователь говорит "создай SLO для [сервис]" — генерируешь документ по шаблону.

### Режим 3: Анализ SLO
Пользователь показывает существующий SLO — ты проверяешь ошибки.

---

## Форматы вывода

Скилл поддерживает 3 формата, выбор через параметр `output_format`:

| Формат | Назначение | Когда использовать |
|--------|------------|-------------------|
| `markdown` | Человекочитаемый документ | Для согласования с бизнесом |
| `yaml` | Конфигурация для GitOps | Для хранения в репозитории |
| `json` | Автоматическая интеграция | Для API, Terraform, мониторинга |

---

## SLI Selection Guide

### Request-driven services (CRUD API)
| SLI Type | Definition | When to use |
|----------|------------|-------------|
| Availability | Proportion of valid requests that were successful | Всегда |
| Latency | Proportion of valid requests faster than threshold | Для синхронных вызовов |
| Quality | Proportion without degradation | Если есть fallback/graceful degradation |

### Pipeline-driven services (ETL/streaming)
| SLI Type | Definition | When to use |
|----------|------------|-------------|
| Freshness | Proportion of data updated recently | Для аналитики |
| Correctness | Proportion of data passed validation | Для денег/compliance |
| Coverage | Proportion of total data processed | Для дата-платформ |

### Storage-driven services (DB/cache/queue)
| SLI Type | Definition | When to use |
|----------|------------|-------------|
| Durability | Proportion of data not lost | Для БД, S3 |
| Throughput | Proportion of time throughput > threshold | Для очередей |
| Read/Write latency | P99 latency | Для кешей |

### Infrastructure (compute/network)
| SLI Type | Definition | When to use |
|----------|------------|-------------|
| Compute availability | CPU/memory not saturated | Для критичных нод |
| Network packet loss | Packet loss < threshold | Для сетевых сервисов |
| Dependency availability | External API available | Для интеграций |
| Queue processing | Messages processed before deadline | Для очередей |

---

## SLO Markdown Template (output_format: markdown)

```markdown
# SLO: [Service Name] - [Objective Name]

## 1. Goal
State the purpose of this SLO (e.g., "Ensure checkout is available and fast").

## 2. SLI Definition
- **Metric Source:** [Prometheus/VictoriaMetrics: http_requests_total]
- **PromQL/EXL:** [paste query here]
- **Numerator:** [e.g., status < 500]
- **Denominator:** [e.g., all valid requests]
- **Measurement Window:** [rolling 28 days]

## 3. SLO Target
| Type | Target | Why |
|------|--------|-----|
| Availability | 99.9% | Standard for critical API |
| Latency | 95% < 300ms | User expectation |

## 4. Error Budget Policy
- **Total allowed error per window:** [e.g., 0.1% = 43 minutes/month]
- **Alerting:**
  - Page: burn rate > 14 (budget gone in 1h)
  - Ticket: burn rate > 3 (budget gone in 8h)
- **Action Policy:**
  - Budget > 75% → Normal changes
  - Budget 25-75% → Усиленный code review
  - Budget < 25% → Reliability fixes only
  - Budget = 0% → Freeze features

## 5. Exclusions
- Load testing traffic (header: `X-Load-Test: true`)
- Well-known crawling bots
- [Define what NOT to measure]

## 6. Example to generate
**Good request (counts as success):** status 200, duration < 300ms
**Bad request (counts as error):** status 500 or timeout > 500ms
**Excluded:** /health endpoint, /metrics
```

---

## SLO YAML Template (output_format: yaml)

```yaml
# SLO Configuration for GitOps / Version Control
# Compatible with: Prometheus Operator, Thanos, Grafana SLO API

apiVersion: sre/v1
kind: ServiceLevelObjective
metadata:
  name: [service-name]-[objective-name]
  namespace: sre
  labels:
    team: [team-name]
    service: [service-name]
    severity: critical
  annotations:
    description: "[Human readable description]"
    owner: "[oncall-handle]"
    review_date: "[YYYY-MM-DD]"

spec:
  # SLO Target
  target: "99.9"  # 99.9% availability
  window: "28d"   # rolling 28 days
  
  # SLI Definition
  sli:
    type: availability  # availability | latency | freshness | correctness
    metric_source: prometheus
    numerator: |
      sum(rate(http_requests_total{status!~"5.."}[5m]))
    denominator: |
      sum(rate(http_requests_total[5m]))
    latency_bucket: ""  # for latency SLI: le="0.3"
    
  # Error Budget
  error_budget:
    policy: rolling_window
    total_errors_percent: 0.1  # 100% - target = 0.1% allowed errors
    alerts:
      - name: severe_burn
        condition: burn_rate > 14
        action: page
      - name: fast_burn
        condition: burn_rate > 6
        action: page_after_15m
      - name: slow_burn
        condition: burn_rate > 2
        action: ticket
    action_policy:
      budget_thresholds:
        - threshold: 75
          action: normal_changes
        - threshold: 25
          action: enhanced_review
        - threshold: 0
          action: feature_freeze
  
  # Exclusions
  exclusions:
    - label: "X-Load-Test"
      value: "true"
      description: "Load testing traffic"
    - path: "/health"
      method: "GET"
      description: "Health checks"
  
  # Historical baseline (for validation)
  baseline:
    measured_availability: "99.92"
    measured_window: "30d"
    date: "[last-month]"
```

---

## SLO JSON Template (output_format: json)

### Для автоматической интеграции с:

1. **Terraform / OpenTofu** — создание SLO как ресурса
2. **Prometheus Operator** — создание SLO CRD через API
3. **VictoriaMetrics Operator** — автоматическая настройка vmalert
4. **CI/CD Pipeline** — проверка SLO compliance при деплое
5. **ChatOps (Telegram/Slack)** — отображение статуса SLO

```json
{
  "$schema": "https://raw.githubusercontent.com/slo/spec/main/schema.json",
  "apiVersion": "sre/v1",
  "kind": "ServiceLevelObjective",
  "metadata": {
    "name": "[service-name]-[objective-name]",
    "namespace": "sre",
    "created_at": "2026-04-24T14:00:00Z",
    "updated_at": "2026-04-24T14:00:00Z",
    "labels": {
      "team": "[team-name]",
      "service": "[service-name]",
      "severity": "critical",
      "environment": "production"
    },
    "annotations": {
      "description": "[Human readable description]",
      "owner": "[oncall-handle]",
      "slack_channel": "#alerts-sre",
      "review_due": "2026-07-24"
    }
  },
  "spec": {
    "target": {
      "value": 99.9,
      "unit": "percent",
      "operator": "gte"
    },
    "window": {
      "duration": "28d",
      "type": "rolling",
      "is_calendar": false
    },
    "sli": {
      "type": "availability",
      "metric_source": "prometheus",
      "queries": {
        "numerator": "sum(rate(http_requests_total{status!~\"5..\"}[5m]))",
        "denominator": "sum(rate(http_requests_total[5m]))",
        "latency_bucket": null
      },
      "thresholds": {
        "critical": 0.999,
        "warning": 0.998,
        "error": 0.995
      }
    },
    "error_budget": {
      "total_errors_allowed": 0.1,
      "burn_rate_alerts": [
        {
          "name": "severe_burn",
          "burn_rate": 14,
          "time_to_exhaust": "1h",
          "severity": "critical",
          "action": "page",
          "promql": "(1 - success_rate) / (1 - 0.999) > 14"
        },
        {
          "name": "fast_burn",
          "burn_rate": 6,
          "time_to_exhaust": "5h",
          "severity": "high",
          "action": "page_after_15m",
          "promql": "(1 - success_rate) / (1 - 0.999) > 6"
        },
        {
          "name": "slow_burn",
          "burn_rate": 2,
          "time_to_exhaust": "17h",
          "severity": "medium",
          "action": "ticket",
          "promql": "(1 - success_rate) / (1 - 0.999) > 2"
        }
      ],
      "action_policy": {
        "thresholds": [
          {
            "remaining_percent": 75,
            "action": "normal_changes",
            "description": "Business as usual"
          },
          {
            "remaining_percent": 25,
            "action": "enhanced_review",
            "description": "All changes require senior review"
          },
          {
            "remaining_percent": 0,
            "action": "feature_freeze",
            "description": "No feature releases until next window"
          }
        ]
      }
    },
    "exclusions": [
      {
        "type": "http_header",
        "name": "X-Load-Test",
        "value": "true",
        "description": "Load testing traffic"
      },
      {
        "type": "http_path",
        "value": "/health",
        "method": "GET",
        "description": "Health check endpoint"
      }
    ],
    "observability": {
      "dashboards": [
        {
          "name": "SLO Dashboard",
          "url": "https://grafana.example.com/d/slo"
        }
      ],
      "metrics_endpoint": "/metrics",
      "alertmanager": "http://alertmanager.monitoring:9093"
    }
  },
  "status": {
    "phase": "active",
    "current_error_budget_remaining": null,
    "last_measurement": null,
    "burn_rate_current": null
  }
}
```

---

## JSON: Пример использования в Terraform

```hcl
# terraform/main.tf
# Создание SLO через Terraform (интеграция с JSON)

resource "local_file" "slo_json" {
  content = jsonencode({
    apiVersion = "sre/v1"
    kind = "ServiceLevelObjective"
    metadata = {
      name = "payment-api-availability"
      labels = {
        team = "payment"
        service = "payment-api"
      }
    }
    spec = {
      target = {
        value = 99.9
      }
      window = {
        duration = "28d"
      }
      sli = {
        type = "availability"
        queries = {
          numerator = "sum(rate(http_requests_total{status!~\"5..\"}[5m]))"
          denominator = "sum(rate(http_requests_total[5m]))"
        }
      }
    }
  })
  filename = "./generated/slo-payment-api.json"
}

# Отправить в Prometheus Operator через kubectl
resource "null_resource" "apply_slo" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.slo_json.filename}"
  }
  depends_on = [local_file.slo_json]
}
```

---

## JSON: Интеграция с VictoriaMetrics vmalert

```yaml
# vmalert config using JSON SLO
groups:
  - name: slo_alerts
    rules:
      - alert: SLOBurnRateHigh
        expr: |
          (1 - sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) 
          / (1 - 0.999) > 14
        for: 5m
        labels:
          severity: critical
          slo_name: "{{ $labels.service }}-availability"
        annotations:
          summary: "SLO budget will exhaust in <1 hour"
          runbook: "https://wiki.example.com/slo-burn"
```

---

## JSON: API для автоматической генерации SLO

```python
# Python example: programmatic SLO generation
import json
import requests
from datetime import datetime, timedelta

def generate_slo(service_name: str, target: float, team: str) -> dict:
    """Generate SLO JSON for API integration"""
    
    slo_template = {
        "apiVersion": "sre/v1",
        "kind": "ServiceLevelObjective",
        "metadata": {
            "name": f"{service_name}-availability",
            "created_at": datetime.utcnow().isoformat(),
            "labels": {
                "team": team,
                "service": service_name,
                "generated_by": "sre-slo-templates"
            }
        },
        "spec": {
            "target": {"value": target},
            "window": {"duration": "28d"},
            "sli": {
                "type": "availability",
                "queries": {
                    "numerator": f'sum(rate({service_name}_requests_total{{status!~"5.."}}[5m]))',
                    "denominator": f'sum(rate({service_name}_requests_total[5m]))'
                }
            }
        }
    }
    return slo_template

# Use it
slo = generate_slo("payment-api", 99.9, "payment-team")
print(json.dumps(slo, indent=2))

# Send to internal SLO API
# response = requests.post("https://slo-api.company.com/v1/slos", json=slo)
```

---

## JSON: Проверка SLO compliance в CI/CD

```bash
#!/bin/bash
# pre-deploy-check.sh
# Проверяет, не превышен ли error budget перед деплоем

# Получить текущий статус SLO из API
curl -s https://slo-api.company.com/v1/slos/payment-api | jq . > slo_status.json

# Проверить остаток бюджета
BUDGET_REMAINING=$(jq '.status.current_error_budget_remaining // 100' slo_status.json)

if (( $(echo "$BUDGET_REMAINING < 10" | bc -l) )); then
    echo "❌ Error budget below 10% ($BUDGET_REMAINING%). Deploy blocked."
    echo "Fix reliability issues before releasing new features."
    exit 1
else
    echo "✅ Error budget OK ($BUDGET_REMAINING%). Proceeding with deploy."
    exit 0
fi
```

---

## Error Budget Best Practices

1. **Window**: Use rolling 28 days (not calendar month)
   - Why: Prevents end-of-month panic and cliff effect

2. **Target**: Don't aim for 100%
   - 99.9% = 8.6 hours downtime/year
   - 99.99% = 52 minutes/year (costs 10x more)

3. **Action policy**: Define consequences
   - >0% budget: Business as usual
   - <25%: Operations review required
   - 0%: Feature freeze until next window

4. **Burn rate alerts** (better than threshold alerts):
   | Severity | Burn Rate | Time to exhaust | Action |
   |----------|-----------|-----------------|--------|
   | Page | >14 | <1 hour | Investigate NOW |
   | High | >6 | ~5 hours | Check in 15m if continues |
   | Ticket | >2 | ~17 hours | Create ticket |
   | Log only | >1 | >28 days | Informational |

   Formula: `burn_rate = error_rate / (1 - slo_target)`

5. **Automate**: Never calculate manually
   - Use Prometheus `slo_*` rules
   - Example: `(1 - slo_target) * window`

---

## Common Mistakes

| Mistake | Why it's bad | Fix |
|---------|--------------|-----|
| SLO = 100% | Zero room for deploys/incidents | 99.9% or 99.99% |
| No SLI defined | Can't measure, useless SLO | Start with HTTP status |
| Only Availability | Miss latency/quality regression | Add latency SLI |
| Calendar month | Budget reset causes panic | Use rolling window |
| Alert at SLO violation | Too late, already degraded | Alert on burn rate >1 |
| No action policy | No one responds to budget depletion | Define concrete steps |
| SLO without business agreement | SRE vs dev mismatch | Negotiate before setting |

---

## PromQL Examples (copy-paste)

### Availability SLI
```promql
# Success rate
sum(rate(http_requests_total{status!~"5.."}[1m])) /
sum(rate(http_requests_total[1m]))
```

### Latency SLI (95% < 300ms)
```promql
# p95 latency
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

### Error Budget Burn Rate
```promql
# Budget exhausted in hours
(1 - slo_target) - (1 - success_rate) / (1 - slo_target) * window
```

### Monthly Error Budget Remaining
```promql
# For 30 day window
(1 - (1 - success_rate)) / (1 - slo_target) * 100
```

---

## SLO Negotiation Process

### Step 1: Find business requirement
Ask: "What happens if service is down for 5 minutes? 1 hour? 1 day?"

### Step 2: Check historical performance
Look at last 30 days of metrics. Current availability is baseline.

### Step 3: Add 1-2% buffer
If current is 99.7%, set SLO at 99.5% (easier to achieve).

### Step 4: Get developer agreement
They must accept the consequences (feature freeze).

### Step 5: Get business sign-off
Product must accept that 0.1% errors are OK.

### Step 6: Review quarterly
Increase SLO gradually, never decrease.

---

## Example: Real SLO Negotiation

**Context:** Payment API, current availability 99.92%

**Business says:** "We need 99.99%!"
**SRE asks:** "That's 52 minutes downtime/year vs current 7 hours. Cost is 10x more. Is it worth?"

**Business:** "No, we can accept current."

**Result SLO:** 99.9% (slightly worse than current, but achievable)

**Lesson:** SLO should be ACHIEVABLE, not aspirational.

---

## Output Format Selection

**Если пользователь не указал `output_format` или указал `markdown`:**
- Выдай человекочитаемый документ по Markdown шаблону
- Добавь пояснения и "why"

**Если пользователь указал `output_format: yaml`:**
- Выдай готовый YAML для GitOps
- Без лишнего текста, только YAML

**Если пользователь указал `output_format: json`:**
- Выдай JSON совместимый со схемой
- Добавь комментарий с инструкцией по использованию
- Пример интеграции: `# Для использования в Terraform/Prometheus Operator`

**Если пользователь просит "интеграция" или "API":**
- Покажи JSON формат
- Добавь примеры кода (Python, bash, Terraform)
