SHELL := /usr/bin/env bash
MODEL ?= qwen2.5-coder:7b-instruct-q4_K_M

.PHONY: help up up-ipex down logs ps pull list rm bench bench-ext health stats demo

help:
	@echo "Backend:"
	@echo "  make up                Arranca Ollama (CPU)"
	@echo "  make up-ipex           Arranca Ollama IPEX-LLM (iGPU Intel, Fase 4)"
	@echo "  make down              Para Ollama"
	@echo "  make logs              docker logs -f"
	@echo "  make ps                Estado del contenedor"
	@echo ""
	@echo "Modelos:"
	@echo "  make pull MODEL=...    Descarga modelo (default: $(MODEL))"
	@echo "  make list              Lista modelos descargados"
	@echo "  make rm MODEL=...      Borra modelo"
	@echo ""
	@echo "Bench y diagnostico:"
	@echo "  make bench MODEL=...   Bench corto (2 prompts)"
	@echo "  make bench-ext MODEL=... [REPS=3]   Bench serio (warm-up + N iters)"
	@echo "  make bench-cmp MODELS='m1 m2 ...'   Comparativa entre modelos"
	@echo "  make health            Estado completo: container + endpoint + tuning"
	@echo "  make stats             Recursos del container ahora mismo"
	@echo "  make demo              Demo reproducible con un doc de luz"
	@echo "  make qeval MODEL=...   Suite de calidad (3 tests, guarda respuestas)"
	@echo ""
	@echo "Cliente agente:"
	@echo "  make code              Launcher: Ollama + opencode en el cwd"
	@echo "  make check             Health check (sin lanzar opencode)"

REPS ?= 3

up:        ; ./scripts/start.sh
up-ipex:   ; ./scripts/start.sh --ipex
down:      ; ./scripts/stop.sh
logs:      ; docker logs -f llmlocal-ollama 2>/dev/null || docker logs -f llmlocal-ollama-ipex
ps:        ; docker ps --filter "name=llmlocal-ollama" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
pull:      ; ./scripts/pull-model.sh $(MODEL)
list:      ; ./scripts/list-models.sh
rm:        ; ./scripts/rm-model.sh $(MODEL)
bench:     ; ./scripts/bench.sh $(MODEL)
bench-ext: ; ./scripts/bench-extended.sh $(MODEL) $(REPS)
bench-cmp: ; ./scripts/bench-compare.sh $(MODELS)
health:    ; ./scripts/health.sh
stats:     ; ./scripts/stats.sh
demo:      ; ./scripts/test-luz.sh $(MODEL)
qeval:     ; ./scripts/quality-eval.sh $(MODEL)
code:      ; ./scripts/code.sh
check:     ; ./scripts/code.sh --check
