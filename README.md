1. ## [sre-guru - SRE консультант](sre-guru/README.md)
2. ## [sre-auditor - SRE аудитор с отчётностью](sre-auditor/README.md)
3. ## [sre-architect - SRE архитектор](sre-slx/README.md)
4. ## [sre-slx - Эксперт по SLO/SLI/EB](sre-slx/README.md)


### todo
- Chaos Engineering: воркфлоу, эсперименты...
- Performance: как искать боттлнеки, профайлить, тюнить...
- Production Readiness: проверка сервиса/продукта на соответствие SRE практикам перед тем, как его выпускать в прод
- продумать роутер: при каих условиях/триггерах какой скилл использовать, типа так:

```
skill_router:
  namespace: "sre"

  routing_rules:

    - match:
        any:
          - "sre"
          - "reliability"
          - "observability"
          - "incident"
          - "oncall"
          - "alerting"
          - "slo"
          - "runbook"
      route_to: "sre_architect"
    - match:
        any:
          - "debug"
          - "troubleshoot"
          - "diagnose"
          - "investigate"
          - "slow"
          - "latency"
          - "performance"
          - "bottleneck"
          - "fix"
          - "remediate"
          - "recover"
          - "rollback"
          - "restart"
          - "scale"
      route_to: "sre_guru"
```

- подумать, есть ли смысл делать один силл, но роутить или лучше несолько скиллов
