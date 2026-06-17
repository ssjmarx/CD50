# CD50 — Cline to Aider Migration Reference

> **Created:** 2026-06-16
> **Status:** Aider installed, configs created, ready for validation

---

## What Was Done

### 1. Aider Installation
- Installed via `uv tool install --python 3.12 aider-chat`
- Used `uv` (Astral) instead of `pip` because Python 3.13 (system default) can't build `numpy==1.24.3`, a transitive dependency of older aider versions. `uv` fetches its own Python 3.12 runtime and resolves dependencies cleanly.
- **Binary location:** `~/.local/bin/aider`
- **Version:** 0.86.2

### 2. Configuration Files Created

| File | Location | Purpose |
|:---|:---|:---|
| `~/.aider.conf.yml` | Global | Default model (glm-5.2), Z.ai endpoint, repo map, git settings |
| `.aider.conf.yml` | `/home/ssjmarx/CD50/` | Project override: glm-4.7 as default, subtree-only, .env loading |
| `.aiderignore` | `/home/ssjmarx/CD50/` | Excludes Godot cache, binary assets, v1 legacy, Aider artifacts |
| `.env.example` | `/home/ssjmarx/CD50/` | Template for API key — copy to `.env` and fill in |
| `CONVENTIONS.md` | `/home/ssjmarx/CD50/` | AI rules file (Aider equivalent of `.clinerules`) |
| `.gitignore` (updated) | `/home/ssjmarx/CD50/` | Added `.env` and Aider artifact exclusions |

### 3. Corrections from Original Plan

| Issue | Original Plan | Fixed To |
|:---|:---|:---|
| **Project path** | `~/Godot/cd50` | `/home/ssjmarx/CD50` (actual working directory) |
| **Model names** | `glm-4.7`, `glm-5.2` | `openai/glm-4.7`, `openai/glm-5.2` (Aider requires provider prefix for LiteLLM routing) |
| **API endpoint** | `https://api.z.ai/api/paas/v4` | `https://api.z.ai/api/coding/paas/v4` (coding plan base URL) |
| **Install method** | `pip3 install aider-chat` | `uv tool install --python 3.12 aider-chat` (avoids numpy/Py3.13 build failure) |
| **API key storage** | In `.aider.conf.yml` directly | In `.env` (gitignored), loaded via `env-file` config key |
| **Config keys** | Some invalid (`voice`, `chat-history-file`, `input-history-file`) | Verified all keys against `aider --help` output |

---

## How to Use Aider for CD50

### First-Time Setup (one-time)
```bash
cd /home/ssjmarx/CD50
cp .env.example .env
# Edit .env and paste your Z.ai API key
nano .env
```

### Daily Usage
```bash
cd /home/ssjmarx/CD50
aider
```
This auto-loads: `.aider.conf.yml` → `.env` → `CONVENTIONS.md`

### Key Commands (inside Aider)
| Command | Purpose |
|:---|:---|
| `/ask <question>` | **Default mode** — read-only reasoning, no file edits |
| `/clear` | Reset context between unrelated topics (saves tokens) |
| `/add <file>` | Load a file into context for review |
| `/tokens` | Check context window usage |
| `/diff` | Review proposed changes before accepting |
| `/model openai/glm-5.2` | Switch to stronger model mid-session |

### Shell Aliases (optional)
Add to `~/.bashrc`:
```bash
alias a='aider'
alias a47='aider --model openai/glm-4.7'
alias a52='aider --model openai/glm-5.2'
alias cd50='cd /home/ssjmarx/CD50 && aider'
```

---

## Migration Validation Checklist

- [ ] Copy `.env.example` to `.env` and paste API key
- [ ] Run `aider --version` — confirms binary is on PATH
- [ ] Start Aider in repo: `cd /home/ssjmarx/CD50 && aider`
- [ ] Test `/ask What is the current goal in memory-bank/03?`
- [ ] Verify repo map builds (shows file count on startup)
- [ ] Check `/tokens` — should be low on a fresh session
- [ ] Confirm `CONVENTIONS.md` is loaded (Aider says "read CONVENTIONS.md")

---

## Token Optimization Notes

1. **Repo map at 2048 tokens** — keeps the architecture overview compact.
2. **`.aiderignore` excludes binary assets** — Godot `.import` files, PNGs, OGGs, etc. would waste thousands of tokens.
3. **`/ask` mode by default** — no edit operations, minimal round-trips.
4. **`/clear` between topics** — prevents context bloat across unrelated discussions.
5. **GLM-4.7 default** — 1× quota vs GLM-5.2's premium tier.

---

## Rollback (if needed)

Aider and Cline can coexist. If Aider doesn't work out:
1. Nothing in this migration breaks Cline — `.clinerules` is untouched.
2. To remove Aider: `uv tool uninstall aider-chat`
3. Config files (`.aider.conf.yml`, `.aiderignore`, `CONVENTIONS.md`) can be deleted or left in place (they're harmless to Cline).