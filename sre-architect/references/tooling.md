# Инструменты

## Принцип

Только self-hosted OpenSource. Managed-обёртки того же продукта (Grafana Cloud, Elastic Cloud, AWS Managed Prometheus, VictoriaMetrics Cloud) исключены так же, как Datadog, New Relic, Dynatrace, Honeycomb, Splunk, Sumo Logic, PagerDuty и Opsgenie: в РФ это вопрос доступности и вендор-лока.

## Стек

| Категория | Инструмент | Лицензия | Когда выбрать |
|-----------|------------|----------|---------------|
| Метрики | Prometheus | Apache 2.0 | стандартный стек, привычные правила |
| Метрики | VictoriaMetrics | Apache 2.0 | много метрик, длительное хранение, мало памяти |
| Метрики (долгое хранение) | Thanos | Apache 2.0 | несколько кластеров Prometheus, глобальный обзор |
| Логи | Loki | AGPL v3 | дешёвое хранение, интеграция с Grafana |
| Логи | Elasticsearch + Kibana | Elastic License 2.0 / SSPL | полнотекстовый поиск, сложные запросы |
| Трейсы | Jaeger | Apache 2.0 | готовый UI, CNCF |
| Трейсы | Tempo | AGPL v3 | хранит трейсы в объектном хранилище |
| Сбор телеметрии | OpenTelemetry Collector | Apache 2.0 | единая точка приёма метрик, логов и трейсов |
| Дашборды | Grafana | AGPL v3 | стандарт де-факто |
| Алерты | Alertmanager | Apache 2.0 | маршрутизация и inhibition |
| Алерты (oncall) | Keep | MIT | расписания, эскалации, интеграции |
| Chaos | Chaos Mesh | Apache 2.0 | сеть, IO, pod-kill |
| Chaos | Litmus Chaos | Apache 2.0 | готовые эксперименты в CI |
| Коммуникация | Telegram, Mattermost | — | доступность в РФ |

AGPL требует внимания, если продукт распространяется: для внутренней эксплуатации ограничений нет, но юридическую проверку лучше сделать заранее.

## Схема сбора

```
Сервисы (метрики / логи / трейсы)
        ↓ OTLP
OpenTelemetry Collector
        ├── VictoriaMetrics или Prometheus → Grafana
        ├── Loki                           → Grafana
        └── Tempo или Jaeger               → Grafana
                        ↓
              Alertmanager → Telegram
                        ↓
                Keep (эскалация)
```

## Как выбрать

| Вопрос | Ответ |
|--------|-------|
| Много метрик, мало памяти? | VictoriaMetrics |
| Уже есть Prometheus и всё работает? | не менять без причины |
| Нужен поиск по логам с агрегациями? | Elasticsearch + Kibana; нужен дешёвый объём — Loki |
| Трейсы хранить месяцами? | Tempo + S3-совместимое хранилище |
| Команда до 10 человек? | Alertmanager + Telegram, Keep не нужен |

## Минимальный набор для старта

1. Метрики RED по каждому сервису: rate, errors, duration (p95 и p99).
2. Четыре алерта: 5xx > 1% за 5 минут, p99 > цели, диск > 85%, сервис недоступен 2 минуты.
3. Логи в JSON с `request_id`.
4. Runbook на каждый алерт.
5. Дашборд на сервис: золотые сигналы на одном экране.

Всё остальное — после того, как это работает.
