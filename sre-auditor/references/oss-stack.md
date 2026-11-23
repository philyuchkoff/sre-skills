# OpenSource стек observability

## Принцип

Предлагай только **self-hosted** варианты. Managed-обёртки того же продукта (Grafana Cloud, Elastic Cloud, AWS Managed Prometheus, VictoriaMetrics Cloud) не предлагай: в РФ это вопрос доступности и вендор-лока, а не вкуса.

Теги образов фиксируй явно. `latest` в проде — находка уровня High.

## Метрики: VictoriaMetrics или Prometheus + Grafana

| Выбор | Когда |
|-------|-------|
| **VictoriaMetrics** | много метрик, ограниченная память, длительное хранение |
| **Prometheus** | стандартный стек, привычные правила и экспортеры |

```yaml
# docker-compose
victoriametrics:
  image: victoriametrics/victoria-metrics:<версия>
  command:
    - "-retentionPeriod=30d"
    - "-storageDataPath=/storage"
  volumes:
    - vm-data:/storage
  ports:
    - "8428:8428"

grafana:
  image: grafana/grafana:<версия>
  environment:
    GF_SECURITY_ADMIN_PASSWORD__FILE: /run/secrets/grafana_admin
  volumes:
    - grafana-data:/var/lib/grafana
  ports:
    - "3000:3000"
```

Полезные запросы для аудита:

```promql
# доля ошибок за 5 минут
sum(rate(http_requests_total{status=~"5.."}[5m]))
  / sum(rate(http_requests_total[5m]))

# p99 задержки
histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```

## Логи: Loki

```yaml
loki:
  image: grafana/loki:<версия>
  command: ["-config.file=/etc/loki/local-config.yaml"]
  ports:
    - "3100:3100"
```

Альтернатива — ELK без X-Pack, если нужен полнотекстовый поиск по большим объёмам. Loki дешевле по ресурсам и проще в эксплуатации.

## Трейсы: Tempo или Jaeger

```yaml
tempo:
  image: grafana/tempo:<версия>
  command: ["-config.file=/etc/tempo.yaml"]
  ports:
    - "3200:3200"   # HTTP API
    - "4317:4317"   # OTLP gRPC
```

Jaeger — если нужен готовый UI и меньше компонентов. В обоих случаях сбор — через OpenTelemetry Collector, сэмплирование начинай с 1%.

## Алерты: Alertmanager + Telegram

```yaml
receivers:
  - name: telegram
    telegram_configs:
      - bot_token_file: /etc/alertmanager/telegram_token
        chat_id: -1001234567890
        parse_mode: HTML
        send_resolved: true

route:
  receiver: telegram
  group_by: [alertname, service]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
```

Токен — только из файла, не в конфиге и не в git.

## Минимальный набор для старта

1. Метрики RED по каждому сервису: rate, errors, duration (p95 и p99).
2. Четыре алерта: 5xx > 1% за 5 минут, p99 > цели, диск > 85%, сервис недоступен 2 минуты.
3. Логи в JSON с `request_id` и уровнем.
4. Runbook на каждый из четырёх алертов — иначе алерт бесполезен.

Дальше — трейсы, SLO и error budget (передать в `sre-slx`).
