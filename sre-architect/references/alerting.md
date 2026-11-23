# Алертинг

Алерт существует для действия. Если после срабатывания никто ничего не делает — алерт удаляется.

## Severity

| Severity | Реакция | Время | Канал | Пример |
|----------|---------|-------|-------|--------|
| P0 | Пейдж | 5 мин | Telegram + звонок | сгорело 2% бюджета за час |
| P1 | Пейдж | 30 мин | Telegram | сгорело 5% бюджета за 6 часов |
| P2 | Тикет | 1 рабочий день | Telegram/тикет | сгорело 10% бюджета за 3 дня |
| P3 | Тикет | неделя | тикет | деградация без влияния на пользователя |
| P4 | Только лог | — | лог | информация для разбора |

## Burn rate: как считать правильно

`burn rate` — во сколько раз быстрее нормы тратится error budget.

```
burn_rate = error_rate / (1 - SLO)
```

где `error_rate` — доля плохих событий за окно, `1 - SLO` — допустимая доля.

Сколько бюджета сгорит за окно `T` и когда он кончится полностью:

```
доля бюджета за T = burn_rate × T / window
время до полного истощения = window / burn_rate
```

Для окна 30 дней (720 часов):

| Burn rate | Длинное окно | Доля бюджета за окно | Полное истощение | Severity |
|-----------|--------------|----------------------|------------------|----------|
| 14.4 | 1 час | 2% | ~50 часов | P0 |
| 6 | 6 часов | 5% | ~5 суток | P1 |
| 1 | 3 дня | 10% | 30 суток | P2 |

Для 28-дневного окна (672 часа) числа другие: 14.4 → 2.1%/час и ~47 часов до истощения. Считай по формуле, не копируй таблицу.

**Важно:** 14.4× не значит «бюджет кончится через час». Это значит «такими темпами сгорит 2% за час» — порог выбран, чтобы поймать пожар рано.

## Multi-window: два окна на каждый уровень

Условие срабатывания — burn rate выше порога и на длинном, и на коротком окне. Короткое окно гасит алерт, когда пожар закончился.

| Severity | Длинное окно | Короткое окно | Порог |
|----------|--------------|---------------|-------|
| P0 | 1h | 5m | 14.4 |
| P1 | 6h | 30m | 6 |
| P2 | 3d | 6h | 1 |

```promql
# burn rate для SLO 99.9% по 5xx
(
  sum(rate(http_requests_total{status=~"5.."}[1h]))
  /
  sum(rate(http_requests_total[1h]))
) / (1 - 0.999)
```

Правило для vmalert/Prometheus:

```yaml
groups:
  - name: slo_burn
    rules:
      - alert: SLOBurnRateCritical
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[1h]))
            / sum(rate(http_requests_total[1h]))
          ) / (1 - 0.999) > 14.4
          and
          (
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            / sum(rate(http_requests_total[5m]))
          ) / (1 - 0.999) > 14.4
        for: 2m
        labels:
          severity: P0
          slo: api-availability
        annotations:
          summary: "SLO api-availability: 2% бюджета сгорает за час"
          runbook_url: "https://wiki.example.com/runbooks/slo-burn"
```

## Alertmanager: маршрутизация и Telegram

`match` устарел, используй `matchers`. Встроенный Telegram-приёмник не требует самописного webhook.

```yaml
route:
  receiver: telegram
  group_by: [alertname, service]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - matchers: ['severity="P0"']
      receiver: telegram-p0
      continue: true
    - matchers: ['severity="P1"']
      receiver: telegram-p1

inhibit_rules:
  - source_matchers: ['severity="P0"']
    target_matchers: ['severity=~"P1|P2"']
    equal: [service]

receivers:
  - name: telegram-p0
    telegram_configs:
      - bot_token_file: /etc/alertmanager/telegram_token
        chat_id: -1001234567890
        parse_mode: HTML
        send_resolved: true
        message: |
          <b>{{ .CommonLabels.alertname }}</b> ({{ .CommonLabels.severity }})
          {{ range .Alerts }}{{ .Annotations.summary }}
          {{ .Annotations.runbook_url }}{{ end }}
  - name: telegram-p1
    telegram_configs:
      - bot_token_file: /etc/alertmanager/telegram_token
        chat_id: -1009876543210
        parse_mode: HTML
        send_resolved: true
```

Токен — только из файла, не в конфиге и не в git.

## Гигиена

- **Inhibition:** P0 подавляет P1/P2 по тому же сервису, иначе один отказ даёт десять сообщений.
- **Silence:** обязателен на время плановых работ, с автозакрытием.
- **Группировка:** по сервису и алерту, не по инстансу.
- **Review:** раз в месяц смотри, какие алерты срабатывали и сколько раз требовали действия. Ноль действий — удаляй.
- **Метрики алертинга:** число пейджей за неделю, доля ложных, время до подтверждения. Растёт число пейджей без роста инцидентов — шум.
