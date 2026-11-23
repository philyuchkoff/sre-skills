#!/usr/bin/env bash
# collect-facts.sh — собирает проверяемые факты о репозитории для SRE-аудита.
#
# Использование:
#   bash scripts/collect-facts.sh [путь]
#
# Печатает markdown в stdout, ничего не меняет в проекте. Содержимое файлов,
# похожих на секреты, не выводится — только имена.
# Совместим с bash 3.2 (macOS): без mapfile и ассоциативных массивов.

set -u

ROOT="${1:-.}"
ROOT="${ROOT%/}"
[ -n "$ROOT" ] || ROOT="/"

if [ ! -d "$ROOT" ]; then
  printf 'Каталог не найден: %s\n' "$ROOT" >&2
  exit 2
fi

FILELIST=$(mktemp "${TMPDIR:-/tmp}/sre-facts.XXXXXX") || exit 2
trap 'rm -f "$FILELIST"' EXIT

# Список файлов проекта без вендорных каталогов и крупных бинарников.
find "$ROOT" -type f \
  -not -path '*/.git/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/vendor/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/.terraform/*' \
  -size -2M -print0 2>/dev/null >"$FILELIST"

say() { printf '%s\n' "$*"; }
hdr() { printf '\n## %s\n\n' "$*"; }
rel() { printf '%s' "${1#"$ROOT"/}"; }

# имена файлов, содержащих регулярное выражение
files_matching() {
  [ -s "$FILELIST" ] || return 0
  # shellcheck disable=SC2016
  xargs -0 grep -lIE "$1" 2>/dev/null <"$FILELIST"
}

# есть ли совпадение в конкретном файле
has() { grep -qIE "$1" "$2" 2>/dev/null; }

count() { wc -l | tr -d ' '; }

# файлы по шаблону имени (find-выражение передаётся целиком)
find_files() {
  find "$ROOT" -type f \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/vendor/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/target/*' \
    -not -path '*/.terraform/*' \
    "$@" 2>/dev/null
}

say "# Факты для SRE-аудита"
say ""
say "- Путь: \`$ROOT\`"

if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  say "- Коммит: \`$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)\` (ветка \`$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)\`)"
fi

say "- Файлов: $(tr -cd '\000' <"$FILELIST" | wc -c | tr -d ' ')"

# ---------------------------------------------------------------- Kubernetes
hdr "Kubernetes"

MANIFESTS=$(files_matching '^kind: (Deployment|StatefulSet|DaemonSet|CronJob|Job|Pod)[[:space:]]*$')

if [ -z "$MANIFESTS" ]; then
  say "Манифестов с workload не найдено."
else
  say "| Манифест | readiness | liveness | resources | grace |"
  say "|---|---|---|---|---|"
  printf '%s\n' "$MANIFESTS" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    r=$(has 'readinessProbe' "$f" && printf 'да' || printf '**нет**')
    l=$(has 'livenessProbe' "$f" && printf 'да' || printf '**нет**')
    res=$(has 'resources:' "$f" && printf 'да' || printf '**нет**')
    g=$(has 'terminationGracePeriodSeconds' "$f" && printf 'да' || printf '—')
    printf '| `%s` | %s | %s | %s | %s |\n' "$(rel "$f")" "$r" "$l" "$res" "$g"
  done
  say ""
  say "- PodDisruptionBudget: $(files_matching '^kind: PodDisruptionBudget' | count) манифест(ов)"
  say "- HorizontalPodAutoscaler: $(files_matching '^kind: HorizontalPodAutoscaler' | count) манифест(ов)"
  say "- topologySpreadConstraints / podAntiAffinity: $(files_matching 'topologySpreadConstraints|podAntiAffinity' | count) файл(ов)"
  say "- Образы с тегом \`latest\`: $(files_matching 'image:[[:space:]]*[^[:space:]]*:latest' | count) файл(ов)"
  say "- NetworkPolicy: $(files_matching '^kind: NetworkPolicy' | count) манифест(ов)"
fi

# -------------------------------------------------------------------- Docker
hdr "Docker"

DOCKERFILES=$(find_files -name 'Dockerfile*')
if [ -z "$DOCKERFILES" ]; then
  say "Dockerfile не найден."
else
  say "| Dockerfile | HEALTHCHECK | USER | base :latest | multi-stage |"
  say "|---|---|---|---|---|"
  printf '%s\n' "$DOCKERFILES" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    hc=$(has '^HEALTHCHECK' "$f" && printf 'да' || printf '**нет**')
    u=$(has '^USER ' "$f" && printf 'да' || printf '**нет**')
    lt=$(has '^FROM .*:latest' "$f" && printf '**да**' || printf 'нет')
    ms=$(has '^FROM .* AS ' "$f" && printf 'да' || printf '—')
    printf '| `%s` | %s | %s | %s | %s |\n' "$(rel "$f")" "$hc" "$u" "$lt" "$ms"
  done
fi

COMPOSE=$(find_files \( -name 'docker-compose*.y*ml' -o -name 'compose.y*ml' \))
if [ -n "$COMPOSE" ]; then
  say ""
  say "| Compose | healthcheck | restart | limits |"
  say "|---|---|---|---|"
  printf '%s\n' "$COMPOSE" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    hc=$(has 'healthcheck:' "$f" && printf 'да' || printf '**нет**')
    rs=$(has 'restart:' "$f" && printf 'да' || printf '**нет**')
    lm=$(has 'mem_limit|deploy:|resources:' "$f" && printf 'да' || printf '**нет**')
    printf '| `%s` | %s | %s | %s |\n' "$(rel "$f")" "$hc" "$rs" "$lm"
  done
fi

# ------------------------------------------------------------------ CI/CD
hdr "CI/CD"

CI_FILES=$(find_files \( -name '.gitlab-ci.yml' -o -name 'Jenkinsfile' -o -name '.drone.yml' -o -name 'azure-pipelines.yml' -o -path '*/.github/workflows/*.yml' -o -path '*/.github/workflows/*.yaml' \))

if [ -z "$CI_FILES" ]; then
  say "Конфигурация CI не найдена."
else
  printf '%s\n' "$CI_FILES" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    say "- \`$(rel "$f")\`"
  done
  say ""
  say "| Признак | Файлов |"
  say "|---|---|"
  say "| откат (rollback / rollout undo) | $(files_matching 'rollback|rollout undo|revert' | count) |"
  say "| canary или blue-green | $(files_matching 'canary|blue.?green' | count) |"
  say "| проверка health/ready перед трафиком | $(files_matching '/ready|/health|wait-for|healthcheck' | count) |"
  say "| миграции БД | $(files_matching 'migrate|migration' | count) |"
  say "| сканирование зависимостей | $(files_matching 'trivy|dependabot|npm audit|pip-audit|govulncheck' | count) |"
fi

# --------------------------------------------------------- признаки в коде
hdr "Признаки в коде"

say "Счёт — число файлов, где признак встречается. Ноль означает «не найдено», а не «не реализовано»: проверь руками."
say ""
say "| Признак | Файлов |"
say "|---|---|"
say "| таймауты | $(files_matching '[Tt]imeout' | count) |"
say "| ретраи и backoff | $(files_matching '[Rr]etr(y|ies)|[Bb]ackoff' | count) |"
say "| circuit breaker | $(files_matching '[Cc]ircuit|gobreaker' | count) |"
say "| graceful shutdown | $(files_matching 'SIGTERM|[Ss]hutdown\(|[Gg]raceful' | count) |"
say "| health / ready эндпоинты | $(files_matching '/health|/ready|healthz|readyz' | count) |"
say "| трассировка | $(files_matching 'opentelemetry|[Oo]tel|jaeger|tempo' | count) |"
say "| request_id / trace_id | $(files_matching 'request_id|requestId|X-Request-Id|trace_id' | count) |"
say "| структуры логов | $(files_matching 'slog|zap|zerolog|logrus|structlog|logback' | count) |"

# ---------------------------------------------------------- документация, DR
hdr "Документация и DR"

DOCS=$(find_files \( -iname 'README*' -o -iname '*runbook*' -o -iname '*playbook*' -o -iname '*slo*' -o -iname '*sla*' -o -iname '*incident*' -o -iname '*restore*' -o -iname '*backup*' -o -iname '*migrat*' -o -iname 'CHANGELOG*' \))

if [ -z "$DOCS" ]; then
  say "Документов не найдено."
else
  printf '%s\n' "$DOCS" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    say "- \`$(rel "$f")\`"
  done
fi

say ""
say "- каталогов docs/: $(find "$ROOT" -type d -name docs -not -path '*/.git/*' 2>/dev/null | count)"
say "- тестов: $(find_files \( -name '*_test.go' -o -name 'test_*.py' -o -name '*.test.ts' -o -name '*.spec.ts' -o -name '*Test.java' \) | count) файл(ов)"

# ------------------------------------------------------------------ секреты
hdr "Похоже на секреты в репозитории"

SECRETS=$(files_matching 'BEGIN [A-Z ]*PRIVATE KEY|password[[:space:]]*[:=][[:space:]]*[^[:space:]]|api[_-]?key[[:space:]]*[:=][[:space:]]*[^[:space:]]')

if [ -z "$SECRETS" ]; then
  say "Совпадений не найдено. Это не гарантия: проверь \`.env\`, CI-переменные и историю git отдельно."
else
  say "Значения не выводятся, только имена файлов:"
  say ""
  printf '%s\n' "$SECRETS" | head -20 | while IFS= read -r f; do
    say "- \`$(rel "$f")\`"
  done
fi

# ------------------------------------------------------------------- выводы
hdr "Что проверить человеком"

say "- Каждая находка в отчёт идёт с \`файл:строка\` и цитатой."
say "- Ноль в таблицах выше — повод открыть файл, а не готовый вывод."
say "- Проверь то, чего скрипт не видит: конфиги кластеров вне репозитория, бэкапы БД, runbooks в вики."
