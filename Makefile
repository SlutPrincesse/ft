.PHONY: test lint format backend-start frontend-start docker-build docker-up

test:
	python -m pytest tests/ -v

lint:
	ruff check backend/

format:
	ruff format backend/

backend-start:
	cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000

frontend-start:
	cd frontend && npm install && npm run dev

docker-build:
	docker compose build

docker-up:
	docker compose up
