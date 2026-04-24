# SRE Architect

> **Principal-level SRE архитектор — проектируем надёжные системы, которые не падают**

Скилл для стратегического проектирования наблюдаемости, отказоустойчивости, SLO и процессов инцидент-менеджмента. 
Используются только OpenSource инструменты.

---

## 🎯 Что делает скилл

| Режим                                 | Что умеет                                                       |
| ------------------------------------- | --------------------------------------------------------------- |
| **Стратегическая консультация**       | Проектирует observability, алертинг, инцидент-менеджмент с нуля |
| **Production Readiness Review (PRR)** | Проводит аудит готовности сервиса к продакшену по 30+ пунктам   |
| **Анализ рисков**                     | Создаёт матрицу рисков с приоритетами Critical/High/Medium/Low  |
| **Chaos Engineering**                 | Проектирует программу хаос-тестирования (Litmus, Chaos Mesh)    |
| **Oncall дизайн**                     | Настраивает ротации, эскалации, Telegram-ботов                  |

---

## 🚀 Быстрый старт

### 1. Запроси архитектуру

```
Спроектируй observability для микросервисной системы из 20 сервисов
```

### 2. Проведи PRR

```
Проведи production readiness review для payment-api
```

### 3. Проанализируй риски

```
Найди слабые места в архитектуре: auth сервис зависит от payment-api и БД
```

### 4. Спроектируй Chaos

```
Как внедрить chaos engineering в компании? Litmus или Chaos Mesh?
```

### 5. Настрой oncall

```
Чем заменить Opsgenie в РФ? Как сделать oncall ротацию через Telegram?
```

---

## 📋 Что проверяет PRR

| Категория         | Что проверяется                                                                  | Количество пунктов |
| ----------------- | -------------------------------------------------------------------------------- | ------------------ |
| **Observability** | Метрики (RPS/errors/latency), логи (JSON + request_id), трейсы, дашборды         | 6                  |
| **Alerting**      | Severity (P0-P4), runbook для каждого алерта, burn rate, эскалации, Telegram бот | 6                  |
| **Resilience**    | Graceful shutdown, timeouts, retries, circuit breaker, PDB, anti-affinity        | 6                  |
| **Documentation** | Runbooks, архитектурная схема, oncall handoff, postmortem template               | 4                  |
| **Testing**       | Нагрузочное тестирование, chaos эксперименты, backup restore                     | 3                  |
| **Communication** | Telegram группы, бот, эскалационные пути                                         | 3                  |

**Итого: 28+ пунктов проверки**

---

## 🛠️ OpenSource инструменты (работают в РФ)

| Задача              | Инструмент            | Лицензия             | Когда использовать                |
| ------------------- | --------------------- | -------------------- | --------------------------------- |
| **Метрики**         | VictoriaMetrics       | Apache 2.0           | Лучше Prometheus по памяти        |
| **Логи**            | Loki                  | AGPL v3              | Интеграция с Grafana              |
| **Трейсы**          | Jaeger / Tempo        | Apache 2.0 / AGPL v3 | Стандарт / Альтернатива           |
| **Дашборды**        | Grafana               | AGPL v3              | Визуализация всего                |
| **Алерты**          | Alertmanager          | Apache 2.0           | CNCF стандарт                     |
| **Алерты (oncall)** | Keep                  | MIT                  | Замена Opsgenie/PagerDuty         |
| **Chaos**           | Litmus Chaos          | Apache 2.0           | CNCF проект, простые эксперименты |
| **Chaos (сеть)**    | Chaos Mesh            | Apache 2.0           | Сложные сетевые сценарии          |
| **Коммуникация**    | Telegram / Mattermost | — / MIT              | Онколлы / Корпоративный чат       |

---

## 📊 Пример матрицы рисков

| Risk ID | Description                      | Likelihood | Impact   | Priority   | Mitigation                       | Owner        | Status      |
| ------- | -------------------------------- | ---------- | -------- | ---------- | -------------------------------- | ------------ | ----------- |
| R-001   | Database single point of failure | High       | Critical | 🔴 Critical | Add replica, failover automation | DBA team     | In progress |
| R-002   | No graceful shutdown             | High       | High     | 🟡 High     | Add signal.Notify                | Backend team | Open        |
| R-003   | No PDB for auth service          | Medium     | High     | 🟡 High     | Add minAvailable:2               | SRE          | Open        |

**Классификация:**
- 🔴 Critical → исправить за 24-72 часа
- 🟡 High → исправить за 2 недели
- 🔵 Medium → исправить за 1 месяц
- ⚪ Low → бэклог

---

## 🚨 Alert Taxonomy (SLO-driven)

| Severity | Response | Response Time | Communication     | Example                             |
| -------- | -------- | ------------- | ----------------- | ----------------------------------- |
| **P0**   | Page     | 2 min         | Telegram + звонок | SLO budget gone in 1h               |
| **P1**   | Page     | 10 min        | Telegram          | SLO budget gone in 6h               |
| **P2**   | Ticket   | 1h            | Telegram (тикет)  | Burn rate > 2                       |
| **P3**   | Ticket   | Next day      | Тикет             | Warning, не влияет на пользователей |
| **P4**   | Log only | Never         | Логи              | Информационные                      |

**Burn Rate Alerts (лучше чем пороговые):**

| Burn Rate | Time to exhaust | Severity | Action                |
| --------- | --------------- | -------- | --------------------- |
| >14       | <1 hour         | P0       | Page on-call          |
| >6        | ~5 hours        | P1       | Page if continues 15m |
| >2        | ~17 hours       | P2       | Create ticket         |
| >1        | >28 days        | P4       | Log only              |

---

## 🔧 Oncall стратегия (только OpenSource)

### Что нужно для онколла:

| Компонент        | Решение                                     |
| ---------------- | ------------------------------------------- |
| Коммуникация     | Telegram группа `@sre_oncall`               |
| Бот для алертов  | Telegram бот + Alertmanager                 |
| Ротация онколлов | Keep (MIT) или Versus Incident (Apache 2.0) |
| Документация     | Wiki.js / BookStack (self-hosted)           |
| Дашборды         | Grafana                                     |

### Минимальный набор за 1 час:

1. Telegram группа `@sre_oncall`
2. Telegram бот + Alertmanager (3 строчки конфига)
3. Runbook на 1 страницу в wiki

### Диагностика: самодельный бот на Python

```python
# telegram_oncall_bot.py
ONCALL_LIST = ["alex", "bob", "charlie"]

async def get_oncall(update, context):
    day = datetime.now().day
    index = day % len(ONCALL_LIST)
    await update.message.reply_text(f"Oncall: {ONCALL_LIST[index]}")
```

---

## 🧨 Chaos Engineering программа

### Рекомендуемые эксперименты:

| Level | Experiment             | Success criteria      | Инструмент |
| ----- | ---------------------- | --------------------- | ---------- |
| 1     | Kill 1 pod             | No SLO violation      | Litmus     |
| 2     | Kill 50% of pods       | HPA works             | Litmus     |
| 3     | Network latency +100ms | Circuit breaker trips | Chaos Mesh |
| 4     | Dependency fails (500) | Fallback works        | Litmus     |
| 5     | Full AZ failure        | Cross-AZ failover     | Chaos Mesh |

### Установка Litmus Chaos:

```bash
kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v3.0.0.yaml
```

### Пример эксперимента Chaos Mesh:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: payment-delay
spec:
  action: delay
  selector:
    pods:
      namespace: production
      labelSelectors:
        app: payment-api
  delay:
    latency: "100ms"
  duration: "5m"
```

---

## 📝 Примеры запросов

### Observability

```
Спроектируй observability для микросервисной системы из 20 сервисов
Как настроить мониторинг в РФ? Только OpenSource
```

### Alerting

```
Помоги спроектировать алертинг для critical API
Дай мне burn rate алерты для SLO 99.9%
Как настроить алерты в Telegram?
```

### Incident Response

```
Спроектируй процесс incident response для команды из 5 SRE
Что нужно для онколла в России?
```

### Risk Assessment

```
Найди слабые места в архитектуре: auth сервис зависит от payment-api и БД
Сделай матрицу рисков для платежного сервиса
```

### Chaos Engineering

```
Как внедрить chaos engineering в компании? Litmus или Chaos Mesh?
Дай пример эксперимента по kill pod
```

### Oncall

```
Чем заменить Opsgenie в РФ?
Как сделать oncall ротацию через Telegram?
Настрой Keep для oncall
```

### PRR

```
Проведи production readiness review для payment-api
```

---

## 🏗️ Архитектурные принципы (SLO-driven)

| Принцип                        | Что значит                                  |
| ------------------------------ | ------------------------------------------- |
| **SLO-first design**           | Каждый компонент имеет SLI/SLO              |
| **Defense in depth**           | Ни одна точка отказа не остаётся без защиты |
| **Observability as a feature** | Метрики, логи, трейсы с первого дня         |
| **Design for on-call**         | Каждый алерт → runbook                      |
| **Reduce blast radius**        | Падение одного сервиса не убивает другие    |
| **Automate everything**        | Если делаешь руками >2 раз — автоматизируй  |

---

## 🚫 Чего скилл НЕ делает

| Не делает                          | Почему                        |
| ---------------------------------- | ----------------------------- |
| Не правит код                      | Это роль `sre-guru` (тактика) |
| Не предлагает коммерческие сервисы | Не работают в РФ              |
| Не принимает security-решений      | Отдельная роль                |
| Не даёт SLO без данных             | Только рекомендации           |

---

## 🔗 Связанные скиллы

| Скилл               | Что делает                                    | Когда использовать                |
| ------------------- | --------------------------------------------- | --------------------------------- |
| `sre-auditor`          | Аудит кода, конфигов, генерация SRE.md        | После архитектуры — проверить код |
| `sre-slx` | Генерация SLO документов (Markdown/YAML/JSON) | Когда SLO согласованы             |

---

## 📄 Формат ответа архитектора

Каждый ответ включает:

### 📌 Executive Summary
Один абзац для CTO/руководителя

### 🏗️ Architectural Design
- Схема компонентов
- Выбор OpenSource технологий
- Trade-offs каждого решения
- Учёт РФ

### 📋 Recommendations by Area
- Observability
- Alerting
- Incident Response
- Resilience
- Testing/Validation
- Oncall Management

### 🚨 Risk Register
Таблица рисков с приоритетами и дедлайнами

### 📅 Roadmap
- Immediate (1 week)
- Near-term (1 month)
- Strategic (3-6 months)

### ✅ Success Metrics
Как измерить успех

### 📱 Communication Setup (только OpenSource)
- Telegram бот
- Telegram группы
- Keep или DIY бот для ротации

---

## ✅ Что проверено (OpenSource, РФ)

| Компонент       | Статус                 |
| --------------- | ---------------------- |
| VictoriaMetrics | ✅ Apache 2.0           |
| Loki            | ✅ AGPL v3              |
| Jaeger / Tempo  | ✅ Apache 2.0 / AGPL v3 |
| Grafana         | ✅ AGPL v3              |
| Alertmanager    | ✅ Apache 2.0           |
| Keep            | ✅ MIT                  |
| Litmus Chaos    | ✅ Apache 2.0           |
| Chaos Mesh      | ✅ Apache 2.0           |
| Telegram        | ✅ Бесплатно, работает  |
| Mattermost      | ✅ MIT                  |

**Нет:** Datadog, New Relic, Dynatrace, Opsgenie, PagerDuty, Slack, Gremlin, Splunk, Sumo Logic, Honeycomb, Lightstep.

---

## 📖 Пример: SRE Architect в действии

**Пользователь:** 
```
Спроектируй observability для платежного сервиса с 10k RPS
```

**Архитектор ответит:**

1. 📌 **Executive Summary:** 
   *"Рекомендую VictoriaMetrics (метрики) + Loki (логи) + Jaeger (трейсы). Это выдержит 10k RPS, не требует коммерческих лицензий."*

2. 🏗️ **Architectural Design:**
   - Схема сбора данных через OpenTelemetry Collector
   - Trade-offs: VictoriaMetrics vs Prometheus (Victoria выигрывает по памяти)
   - Учёт РФ: всё поднимается в своём кластере

3. 📋 **Recommendations:**
   - Метрики: RED/USE, 5-15 секунд разрешение
   - Алерты: burn rate, Telegram + Keep
   - Oncall: ротация через Keep, эскалация в Telegram

4. 🚨 **Risk Register:**
   - Без PDB → 🔴 Critical
   - Нет circuit breaker на внешние API → 🟡 High

5. 📅 **Roadmap:**
   - Неделя 1: VictoriaMetrics + Grafana
   - Неделя 2-3: Логи, трейсы
   - Месяц 2-3: SLO, алерты, oncall

---

## 🤝 Вклад в скилл

Нашли коммерческий инструмент в рекомендациях? Откройте Issue.  
Хотите добавить OpenSource инструмент? PR приветствуется.

---

## 📄 Лицензия

MIT — используйте свободно, адаптируйте под свои задачи.

---

**Вопросы или предложения?** Откройте Issue.