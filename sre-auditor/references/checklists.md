# Чек-листы по слоям

Каждый пункт — проверяемый по репозиторию. Колонка «Как проверить» указывает, где искать доказательство. Пункт, который проверить нельзя, в отчёт не идёт.

## Код

| Проверка | Как проверить |
|----------|---------------|
| Таймаут на каждом внешнем вызове | найти клиентов HTTP/gRPC/БД: `grep -rn "http.Client\|dialTimeout\|context.WithTimeout"` |
| Ретраи с exponential backoff и jitter | `grep -rn "retry\|backoff"`, проверить наличие jitter и лимита попыток |
| Circuit breaker на критичных зависимостях | `grep -rn "circuit\|breaker\|gobreaker"` |
| Graceful shutdown по SIGTERM | `grep -rn "signal.Notify\|Shutdown(\|SIGTERM"` |
| Health-эндпоинты `/health` и `/ready` разделены | роутер: `/health` не проверяет зависимости, `/ready` проверяет |
| `request_id` сквозь все слои | `grep -rn "request_id\|X-Request-Id\|trace_id"` |
| Нет `panic` в проде без recover | `grep -rn "panic("` и middleware с `recover` |
| Идемпотентность ретраев (POST/платежи) | ключи идемпотентности в обработчиках записи |

## Инфраструктура

| Проверка | Как проверить |
|----------|---------------|
| `requests` и `limits` заданы | манифесты: `grep -n "resources:" -A4` |
| `readinessProbe` и `livenessProbe` | `grep -n "readinessProbe\|livenessProbe"` |
| `PodDisruptionBudget` при 2+ репликах | `grep -rn "kind: PodDisruptionBudget"` |
| `topologySpreadConstraints` или anti-affinity | `grep -rn "topologySpreadConstraints\|podAntiAffinity"` |
| `terminationGracePeriodSeconds` ≥ времени дренажа | значение в манифесте против таймаута shutdown |
| `HPA` или описан ручной scale-план | `grep -rn "kind: HorizontalPodAutoscaler"` |
| Образы с фиксированным тегом, не `latest` | `grep -rn "image:"` |
| Секреты не в манифестах и не в git | `grep -rn "password\|token\|secret"` по манифестам, наличие `.env` в `.gitignore` |
| PersistentVolume: класс, ретеншн, бэкап | `grep -rn "kind: PersistentVolumeClaim"` |

## Observability

| Проверка | Как проверить |
|----------|---------------|
| Метрики RED: rate, errors, duration | конфиг приложения или экспортера |
| Гистограммы, а не только средние | `grep -rn "Histogram\|histogram_quantile"` |
| Логи структурные (JSON) с уровнем и `request_id` | настройка логгера, пример строки |
| Трейсы с сэмплированием | `grep -rn "otel\|jaeger\|tempo"` |
| Алерты на 5xx, задержку, насыщение | `grep -rn "alert:"` в правилах Prometheus |
| Алерты не дублируют друг друга | 5–10 правил на сервис — норма; 50 — шум |
| Есть дашборд сервиса | JSON дашбордов в репозитории или ссылка |

## CI/CD

| Проверка | Как проверить |
|----------|---------------|
| Откат за минуту | job rollback или описанная процедура |
| Health check перед переключением трафика | шаг деплоя ждёт `/ready` |
| Canary или blue-green | шаги с раскаткой на долю трафика |
| Миграции БД с возможностью отката | миграции отдельным шагом, до деплоя, с бэкапом |
| Тесты блокируют мерж | required checks в CI |
| Сканирование зависимостей | job `audit`/`trivy`/`dependabot` |

## DR и бэкапы

| Проверка | Как проверить |
|----------|---------------|
| Бэкап по расписанию | cron, оператор БД, конфиг бэкапа |
| Восстановление проверяли | документ с датой последней проверки |
| RTO и RPO описаны | `docs/`, README |
| Бэкап лежит вне основного региона | конфиг хранилища |
| Retention соответствует требованиям | политика хранения |

## Документация

| Проверка | Как проверить |
|----------|---------------|
| Runbook на топ-3 отказа | `docs/`, `runbooks/` |
| SLO и error budget | документ с целевыми значениями |
| Политика эскалации и on-call | документ, график дежурств |
| Схема архитектуры | `docs/`, `assets/` |
| Инструкция локального запуска | README |
