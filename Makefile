.PHONY: help build up down logs console db-migrate db-seed db-reset test clean rebuild-app health

help:
	@echo "Hyrax COAR Notify Docker Commands"
	@echo "================================="
	@echo ""
	@echo "Getting Started:"
	@echo "  make build           - Build Docker images"
	@echo "  make up              - Start all services"
	@echo "  make down            - Stop all services"
	@echo "  make clean           - Stop services and remove volumes"
	@echo ""
	@echo "Database:"
	@echo "  make db-create       - Create databases"
	@echo "  make db-migrate      - Run database migrations"
	@echo "  make db-seed         - Seed database with sample data"
	@echo "  make db-reset        - Reset database (drop and recreate)"
	@echo ""
	@echo "Development:"
	@echo "  make console         - Open Rails console"
	@echo "  make logs            - View all service logs"
	@echo "  make logs-app        - View app logs only"
	@echo "  make logs-solr       - View Solr logs only"
	@echo "  make logs-fcrepo     - View Fedora logs only"
	@echo ""
	@echo "Testing:"
	@echo "  make test            - Run all tests"
	@echo "  make test-unit       - Run unit tests"
	@echo "  make test-system     - Run system tests"
	@echo ""
	@echo "Maintenance:"
	@echo "  make health          - Check service health"
	@echo "  make rebuild-app     - Rebuild Rails app"
	@echo "  make shell           - Open shell in app container"
	@echo ""

build:
	docker-compose build

up:
	docker-compose up -d
	@echo ""
	@echo "Services starting... Waiting for health checks..."
	@sleep 5
	@make health

down:
	docker-compose down

clean:
	docker-compose down -v

logs:
	docker-compose logs -f

logs-app:
	docker-compose logs -f app

logs-solr:
	docker-compose logs -f solr

logs-fcrepo:
	docker-compose logs -f fcrepo

console:
	docker-compose exec app bundle exec rails console

db-create:
	docker-compose exec app bundle exec rails db:create

db-migrate:
	docker-compose exec app bundle exec rails db:migrate

db-seed:
	docker-compose exec app bundle exec rails db:seed

db-reset:
	docker-compose exec app bundle exec rails db:reset

test:
	docker-compose exec app bundle exec rspec

test-unit:
	docker-compose exec app bundle exec rspec spec/models spec/controllers

test-system:
	docker-compose exec app bundle exec rspec spec/system

shell:
	docker-compose exec app /bin/bash

health:
	@echo "Checking service health..."
	@echo ""
	@docker-compose ps
	@echo ""
	@echo "Health status:"
	@docker-compose exec postgres pg_isready -U postgres || echo "PostgreSQL: Not ready"
	@docker-compose exec redis redis-cli ping >/dev/null 2>&1 && echo "Redis: Healthy" || echo "Redis: Not ready"
	@curl -s http://localhost:8983/solr/admin/ping | grep -q "OK" && echo "Solr: Healthy" || echo "Solr: Not ready"
	@curl -s http://localhost:8984/fcrepo/rest/ >/dev/null 2>&1 && echo "Fedora: Healthy" || echo "Fedora: Not ready"
	@echo ""
	@echo "Access URLs:"
	@echo "  Rails App: http://localhost:3000"
	@echo "  Solr Admin: http://localhost:8983/solr"
	@echo "  Fedora UI: http://localhost:8984/fcrepo/rest"
	@echo "  Database Admin: http://localhost:8080"

rebuild-app:
	docker-compose up -d --build app
	@echo "App rebuilt and restarted"

install-gems:
	docker-compose exec app bundle install

ps:
	docker-compose ps

restart:
	docker-compose restart

restart-app:
	docker-compose restart app

rm-volumes:
	docker volume rm $$(docker volume ls -q | grep hyrax)

setup: build up db-create db-migrate
	@echo ""
	@echo "✓ Hyrax COAR Notify setup complete!"
	@echo "Access the application at: http://localhost:3000"
