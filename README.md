# youtrack-arm
Это неофициальная сборка YouTrack для raspberry pi основанная на arm32v7/adoptopenjdk и официальном образе jetbrains/youtrack.

Сборка происходит автоматически, каждую субботу, если появился новый тэг в официальном репозитории.

Пример helmfile.yaml:
```
---
repositories:
  - name: minicloudlabs
    url: https://minicloudlabs.github.io/helm-charts

releases:
  - name: youtrack
    namespace: youtrack
    chart: minicloudlabs/youtrack
    version: 1.0.7
    values:
      - persistence:
          enabled: true
      - image:
          repository: litded/youtrack-arm
          tag: "2023.2.20316"
```
