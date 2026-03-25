# 🏛️ Архитектура и руководство по пайплайну

Этот документ описывает внутреннее устройство `drifter`: структуру шаблонов, bootstrap-сценарии, модель миграции конфигов и жизненный цикл `chezmoi` source.

👉 Быстрая установка и базовые сценарии находятся в [README.md](README.md).

---

## 1. Архитектурная философия и технологический стек

В основе проекта лежит недеструктивное внедрение shell-конфигов и единый source of truth через `chezmoi`. Репозиторий проектируется так, чтобы:

- не стирать существующие пользовательские конфиги;
- давать один набор шаблонов для нескольких shell;
- деградировать к системным утилитам, если современный CLI недоступен;
- обновляться на разных машинах через один и тот же `chezmoi` workflow.

### 1.1 Ядро и оболочка

- **Bash:** базовый shell и главный entrypoint интерактивной среды.
- **Ble.sh:** улучшает интерактивный `bash`, не меняя shell-модель проекта.
- **Fish:** опциональный интерактивный слой, подключаемый через локальные flags.
- **PowerShell:** отдельная Windows-ветка конфигурации с собственным bootstrap.

Практика выбора shell внутри проекта такая:

- `bash` считается основным и safest default;
- `fish` рассматривается как локальный интерактивный апгрейд, а не обязательная база;
- `zsh` поддерживается как совместимый пользовательский shell, если он уже выбран на машине.

### 1.2 Управление конфигурациями

**Chezmoi** выступает source of truth для dotfiles и точкой применения шаблонов на целевой машине. Machine-specific поведение задаётся локальными данными в `chezmoi.toml`, а не форками репозитория.

### 1.3 Prompt и CLI-инструменты

- **Starship** даёт единый prompt для нескольких shell.
- **`eza`, `bat`, `zoxide`, `fzf`, `ripgrep`, `fd`** используются как preferred tooling.
- Итоговые alias генерируются с фоллбэками, чтобы shell не ломался на машинах без этих утилит.

---

## 2. Структура конфигурационного хранилища `chezmoi`

```text
~/.local/share/chezmoi/
  dot_bashrc.tmpl               # Входной интерактивный скрипт инициализации bash
  dot_config/
    shell/
      env.list                  # Общие переменные окружения
      aliases.sh.tmpl           # Центр инициализации alias
    fish/
      config.fish.tmpl          # Опциональный fish-конфиг
    starship.toml               # Конфигурация prompt
  Documents/
    PowerShell/
      Microsoft.PowerShell_profile.ps1.tmpl
                                # Профиль PowerShell 7+
    WindowsPowerShell/
      Microsoft.PowerShell_profile.ps1.tmpl
                                # Профиль Windows PowerShell 5.1
  scripts/
    install.sh                  # One-command Linux/WSL install
    install-powershell.ps1      # One-command Windows install
    bootstrap.sh                # Локальный bootstrap
    bootstrap-remote.sh         # Удалённый bootstrap по SSH
    bootstrap-powershell.ps1    # Windows bootstrap через Scoop + chezmoi
```

### 2.1 Единый источник истины

Базовые env и alias вынесены в `env.list` и `aliases.sh.tmpl`, чтобы минимизировать дублирование между Bash, Zsh, Fish и PowerShell-веткой.

### 2.2 Механизм адаптивной деградации

Шаблон `aliases.sh.tmpl` использует `lookPath`, чтобы на этапе генерации выбирать modern CLI или безопасный системный fallback.

---

## 3. Регламенты внедрения и безопасности

Сценарии `bootstrap.sh` и `bootstrap-remote.sh` рассчитаны на недеструктивную установку.

### 3.1 Стратегия резервного копирования

Оригинальные пользовательские файлы (`~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish`, `starship.toml`) копируются в:

`~/.shell-migration-backup/YYYYMMDD-HHMMSS/`

### 3.2 Мягкий сброс (Soft Reset)

Режим по умолчанию. Существующие конфиги переименовываются в `*.legacy`, а новые entrypoint-файлы продолжают их source-ить.

### 3.3 Жёсткий сброс (Hard Reset)

Активируется через `./scripts/hard-reset-shell-configs.sh` или `--reset-mode hard`, если legacy-конфиги мешают стабильной работе новой среды.

---

## 4. Специфичные локальные конфигурации

Machine-specific поведение задаётся через `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
use_fish = false
use_blesh = false
legacy_zsh = true
use_powershell = true
```

После изменения локальных flags нужно выполнять `chezmoi apply`.

---

## 5. Процедура отката конфигураций

Для деинсталляции:

1. Перейти в клон репозитория или `~/.local/share/chezmoi/`.
2. Запустить `./scripts/hard-reset-shell-configs.sh`.
3. Восстановить оригинальные файлы из `~/.shell-migration-backup/<timestamp>/`.

---

## 6. Поведение ключевых конфигураций

### 6.1 Starship

`dot_config/starship.toml` задаёт единый prompt и реактивные индикаторы состояния для shell, которые его поддерживают.

### 6.2 Alias generation

`dot_config/shell/aliases.sh.tmpl` генерирует итоговые alias с учётом доступных бинарей на конкретной машине.

### 6.3 FZF preview

`dot_config/shell/env.list` задаёт `FZF_DEFAULT_OPTS` с каскадным preview через `bat`, `batcat` или `cat`.

### 6.4 Shell-specific adapters

- Bash использует `ble.sh`, `fzf --bash`, `zoxide init bash`, `starship init bash`.
- Zsh использует `fzf --zsh` с fallback на системные key bindings.
- Fish использует `fzf --fish` с fallback на системные fish-скрипты.
- PowerShell использует отдельные профили и `PSFzf`.

---

## 7. Жизненный цикл инфраструктуры

### 7.1 Редактирование конфигураций

Генерируемые файлы в домашней директории не являются source of truth. Изменения нужно вносить через `chezmoi edit`, затем применять через `chezmoi apply`.

### 7.2 Публикация и синхронизация версий

Обычный поток:

1. Изменить source.
2. Закоммитить и запушить репозиторий.
3. На целевой машине выполнить `chezmoi update`.

Важно различать:

- `chezmoi update` обновляет active source;
- `chezmoi apply` применяет уже существующий source.

### 7.3 Управление секретами

Секреты не должны попадать в versioned общие env-файлы. Для machine-local данных использовать отдельные локальные файлы или secret backend.

---

## 8. Синхронизация удалённых хостов

### 8.1 Один сервер

Для одного сервера достаточно:

```bash
chezmoi update
```

### 8.2 Несколько серверов

Для нескольких серверов используется `scripts/sync-all-remotes.sh`, который запускает `chezmoi update` по массиву `HOSTS`.

---

## 9. Расширенные сценарии запуска

### 9.1 `bootstrap.sh` — локальная установка

Примеры:

```bash
./scripts/bootstrap.sh --reset-mode hard -y
./scripts/bootstrap.sh --skip-packages
./scripts/bootstrap.sh --skip-backup --skip-reset
./scripts/bootstrap.sh --repo-url git@github.com:Ephraimus/drifter.git --repo-branch main
```

Основные флаги:

| Флаг | Описание |
| --- | --- |
| `--source-dir DIR` | Локальный starter-kit directory |
| `--repo-url URL` | Использовать удалённый Git-репозиторий |
| `--repo-branch BRANCH` | Ветка для `--repo-url` |
| `--use-fish` | Установить Fish и активировать fish-конфиг |
| `--reset-mode soft\|hard` | Режим сброса |
| `--set-login-shell bash\|fish\|zsh\|skip` | Попробовать изменить login shell через `chsh` |
| `--skip-packages` | Не ставить системные пакеты |
| `--skip-backup` | Не делать backup |
| `--skip-reset` | Не переименовывать текущие конфиги |
| `-y, --yes` | Неинтерактивный режим |

Важно: `--set-login-shell` не гарантирует смену shell. Для успеха нужен установленный shell, запись в `/etc/shells` и успешный вызов `chsh`. Если шаг не сработал, bootstrap печатает готовую ручную команду.

### 9.2 `bootstrap-remote.sh` — удалённая установка по SSH

Примеры:

```bash
scp -r ./ user@host:/tmp/drifter-kit
ssh user@host 'bash /tmp/drifter-kit/scripts/bootstrap-remote.sh --starter-kit-dir /tmp/drifter-kit'
```

```bash
cat ./scripts/bootstrap-remote.sh | ssh user@host 'bash -s -- --repo-url https://github.com/Ephraimus/drifter.git --use-fish --set-login-shell fish'
```

```bash
cat ./scripts/bootstrap-remote.sh | ssh -o StrictHostKeyChecking=no deploy@host 'bash -s -- --repo-url https://github.com/Ephraimus/drifter.git --yes --skip-backup'
```

### 9.3 PowerShell на Windows

Windows-specific installation and verification вынесены в [POWERSHELL.md](POWERSHELL.md).

### 9.4 `sync-all-remotes.sh` — массовая синхронизация

Использование:

```bash
./scripts/sync-all-remotes.sh
```

Разовый эквивалент для одного сервера:

```bash
ssh user@host 'chezmoi update'
```
