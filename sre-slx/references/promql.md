# PromQL для SLO

Запросы для Prometheus и VictoriaMetrics (MetricsQL поддерживает те же функции). Все примеры — для SLO 99.9% и окна 28 дней.

## Доступность

```promql
# SLI: доля успешных запросов
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

```promql
# error rate: доля плохих запросов
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

Не смешивай в одном SLI разные пути. Если нужен общий SLI по сервису — суммируй метрики, но исключи `/health`, `/metrics` и служебные эндпоинты:

```promql
sum(rate(http_requests_total{status!~"5..", route!~"/health|/metrics"}[5m]))
/
sum(rate(http_requests_total{route!~"/health|/metrics"}[5m]))
```

## Задержка

SLI задержки — доля запросов быстрее порога, а не p95:

```promql
# доля запросов быстрее 300 мс
sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

p95 нужен для диагностики, но SLO на нём не строится: p95 = 300 мс не говорит, сколько пользователей страдает.

## Burn rate

```promql
# burn rate за 1 час для SLO 99.9%
(
  sum(rate(http_requests_total{status=~"5.."}[1h]))
  / sum(rate(http_requests_total[1h]))
) / (1 - 0.999)
```

Для второй пары окон меняются только интервалы: `[5m]` для короткого окна, `[6h]`/`[30m]` для P1, `[3d]`/`[6h]` для P2.

## Остаток бюджета

```promql
# 1 — бюджет цел, 0 — исчерпан, <0 — перерасход
1 - (
  (
    sum(increase(http_requests_total{status=~"5.."}[28d]))
    / sum(increase(http_requests_total[28d]))
  ) / (1 - 0.999)
)
```

`increase` на длинном окне чувствителен к пропускам данных: если сборщик падал, значение исказится. Проверяй `up` и наличие дыр в данных за окно.

## Recording rules

Считай SLI и burn rate заранее, чтобы дашборд и алерты не пересчитывали одно и то же:

```yaml
groups:
  - name: slo_recording
    interval: 30s
    rules:
      - record: slo:http_error_ratio:1h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1h]))
          / sum(rate(http_requests_total[1h]))

      - record: slo:http_burn_rate:1h
        expr: slo:http_error_ratio:1h / (1 - 0.999)
```

Именование: `slo:<метрика>:<агрегация>` — так правила читаются без комментариев.

## Исключения

Исключение работает только если признак есть в метках. Примеры:

```promql
# не считать нагрузочные тесты
http_requests_total{load_test!="true"}

# не считать внутренние вызовы
http_requests_total{client!="internal"}
```

Если исключить нечем — либо добавь метку в код, либо признай, что SLI будет зашумлён.

## Частые ловушки

| Ловушка | Что не так |
|---------|------------|
| `rate(...[1m])` для SLI | слишком шумно, скользит от одного запроса |
| `irate` для длинных окон | показывает последнюю пару точек, а не тренд |
| `avg(latency)` | средняя скрывает хвост |
| `sum(rate(...)) / sum(rate(...))` без `by` | смешивает разные сервисы в один SLI |
| `[28d]` в графике на 15 секунд | тяжёлый запрос на каждый рендер, нужен recording rule |
| деление на ноль | нет трафика → `NaN`; добавь `or vector(1)` для знаменателя, если это ожидаемо |
