# ORK3 - Amtgard Online Record Keeper

## Project Overview

ORK3 is a PHP 8.1 web application for managing the Amtgard LARP organization's records. It handles player management, event scheduling, tournament tracking, awards, attendance, treasury, and administrative functions across a hierarchy of Kingdoms and Parks.

**Live URL:** https://ork.amtgard.com/orkui/

## Architecture

The application follows a custom three-tier MVC architecture:

- **orkui/** - UI layer (controllers, models, templates)
- **orkservice/** - SOAP/JSON web service API layer (23 service modules)
- **system/** - Shared core libraries and framework classes

### Key Directories

| Path | Purpose |
|------|---------|
| `orkui/controller/` | MVC controllers (`controller.Name.php` -> `Controller_Name`) |
| `orkui/model/` | MVC models (`model.Name.php` -> `Model_Name`) |
| `orkui/template/default/` | Templates (`.tpl` files), JS, CSS, images |
| `orkui/language/default/en/` | Internationalization (`.lang` files) |
| `orkservice/{Module}/` | SOAP service modules (Service.php, definitions, functions, tests) |
| `system/lib/ork3/` | Core business logic classes (`class.Name.php`) |
| `system/lib/system/` | Framework classes (Controller, Model, View, Session, Request, etc.) |
| `system/lib/Yapo2/` | Custom ORM / database abstraction layer |
| `db-migrations/` | SQL migration scripts (2017-2022) |
| `assets/` | Uploaded files (heraldry, player images, waivers) |

## Technology Stack

- **Language:** PHP 8.1
- **Web Server:** NGINX + PHP-FPM
- **Database:** MariaDB/MySQL (100+ tables, prefixed `ork_`)
- **Caching:** Memcached
- **ORM:** Yapo2 (custom)
- **Web Services:** SOAP (nusoap library) and JSON (custom JsonServer)
- **Templates:** Custom PHP-based View engine (`.tpl` files)
- **Containerization:** Docker / Docker Compose

## Development Environment

### Docker Setup

```bash
# Start development environment
docker-compose -f docker-compose.php8.yml up

# Start in background
docker-compose -f docker-compose.php8.yml up -d
```

- **App URL:** http://localhost:19080/orkui/
- **Database:** localhost:24306 (user: `ork` / password: `secret`, root: `root` / `root`)

### Database Initialization

```bash
mysql -P 24306 --protocol=tcp -h localhost -u root -proot ork < [redacted-db-dump].sql
SET GLOBAL sql_mode = '';
```

There is no npm, composer, or build step. PHP files are served directly via NGINX/PHP-FPM from the Docker container.

## Code Conventions

### Naming Patterns

- Controllers: `controller.{Name}.php` containing class `Controller_{Name}`
- Models: `model.{Name}.php` containing class `Model_{Name}`
- Core classes: `class.{Name}.php` in `system/lib/ork3/`
- Framework classes: `class.{Name}.php` in `system/lib/system/`
- Service modules: each in `orkservice/{Module}/` with `Service.php`, `Service.definitions.php`, `Service.function.php`, `Service.registration.php`, `Service.test.php`

### Routing

URL pattern: `/orkui/index.php?Route=Controller/method/action`

### Models and Services

Models in `orkui/model/` proxy calls through `APIModel` to core business logic classes in `system/lib/ork3/`. The `startup.php` bootstrap script auto-loads all classes using `scandir()` and reflection.

### Templates

The View engine searches for templates in order:
1. Kingdom-specific templates
2. Theme-specific templates
3. Default templates (`orkui/template/default/`)

Template files are plain PHP (`.tpl` extension) with no template language.

### Authentication & Authorization

- Session-based authentication with 72-hour timeout
- Token-based API authentication for services
- Role-based authorization: admin, kingdom, park, officer levels
- Player banning and IP restriction support

## Database

- Tables are prefixed with `ork_` (e.g., `ork_mundane` for players, `ork_kingdom`, `ork_park`)
- Key tables: `ork_mundane` (players), `ork_kingdom`, `ork_park`, `ork_event`, `ork_tournament`, `ork_attendance`, `ork_award`, `ork_authorization`, `ork_account` (treasury), `ork_unit`
- Schema defined in `ork.sql`
- Migrations in `db-migrations/` (numbered SQL files)

## Debugging

- Set `TRACE` and `DUMPTRACE` constants in config for logging
- Use `logtrace()` function throughout the codebase
- Logs written to `system/logs/`
- Config setting `APP_STAGE: DEV` enables development mode

## Important Notes

- No automated test runner or CI pipeline is configured in the repository. Service test files exist in `orkservice/` modules but there is no unified test command.
- The codebase uses SHA1 password hashing (legacy). Be cautious when modifying authentication code.
- The `orkmobile/` directory is a git submodule placeholder (currently empty).
- Legal requirement: contributors must sign a Work for Hire Transfer Agreement (contact technicalad@amtgard.com).
