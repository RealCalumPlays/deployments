# HAProxy Topology Guidance

This document covers HAProxy mode selection and topology decisions for the
`ai_horde` role. For variable reference and basic usage, see
[roles/ai_horde/README.md](../roles/ai_horde/README.md).

## Mode Selection

- **Shared hosts** with existing HAProxy config: use `safe_edit` and a
  non-privileged ingress port (for example `8080`).
- **Dedicated ingress hosts**: `standalone` can be appropriate, including
  privileged ingress ports.
- **Managed reverse proxy environments**: prefer upstream ingress and keep
  `ai_horde_install_haproxy=false` unless local HAProxy is explicitly needed.

## Privileged Binding

Binding ports below `1024` (for example `80/443`) is privileged and may
conflict with existing ingress services. Validate ownership, firewall rules,
and certificate strategy before enabling.

## Reverse-Proxy Layering

Copy/paste baseline for running AI-Horde behind an upstream reverse proxy:

```yaml
ai_horde_install_haproxy: true
ai_horde_haproxy_mode: safe_edit
ai_horde_haproxy_port: 8080
ai_horde_listen: "127.0.0.1"
```

In this pattern, your upstream reverse proxy owns `80/443` and forwards API
traffic to AI-Horde on `:8080`.

## Operator Decision Matrix

| Topology | Recommended HAProxy mode | Baseline ingress port | Notes |
| ---- | ---- | ---- | ---- |
| Single-host lab | `safe_edit` | `8080` | Lowest-conflict local baseline; easy to place another proxy in front later. |
| Shared host with existing HAProxy | `safe_edit` | `8080` | Preserves unrelated HAProxy configuration via marker-bounded edits. |
| Dedicated ingress host | `standalone` | `80` (and/or `443` via external TLS strategy) | Full config ownership is acceptable when no other stack owns HAProxy. |
| Managed reverse proxy upstream | `disabled` (`ai_horde_install_haproxy=false`) | Upstream-owned | Keep AI-Horde behind upstream ingress; avoid duplicate proxy ownership. |
