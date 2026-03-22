# 🌍 Drifter — Единая Терминальная Среда

Единая и предсказуемая среда командной строки для Linux, WSL, удалённых SSH-хостов и Windows PowerShell.

`drifter` — это репозиторий с dotfiles и bootstrap-скриптами. Он ставит и обновляет shell-конфиги через `chezmoi`, сохраняя существующие пользовательские файлы как `*.legacy`.

## Что Даёт Drifter

Проект фокусируется на доставке и поддержке конкретной terminal-конфигурации:

1. **Bash как базовый shell.** `bash` остаётся совместимой основой, а `ble.sh` и `starship` добавляют современный интерактивный UX.
2. **Единые конфиги для нескольких shell.** Базовые env/alias централизованы, а `zsh`, `fish` и PowerShell используют ту же общую конфигурационную модель.
3. **Адаптивные фоллбэки.** Если на машине нет `eza`, `bat` или других современных CLI, итоговые конфиги откатываются к безопасным системным эквивалентам.
4. **Недеструктивная миграция.** Установка делает backup и переименовывает существующие shell-конфиги в `*.legacy`, а не стирает их.

## Технологический стек

- **Chezmoi** — source of truth для dotfiles и шаблонизации.
- **Bash + Ble.sh** — базовая интерактивная среда.
- **Starship** — единый prompt для разных shell.
- **Modern CLI** — `eza`, `bat`, `zoxide`, `fd`, `ripgrep`, `fzf`.
- **PowerShell** — отдельные профили для `PowerShell 7+` и `Windows PowerShell 5.1`.

## Быстрый старт

### Установка одной командой
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Ephraimus/drifter/main/scripts/install.sh)"
```

### Локальная установка из уже клонированного репозитория
```bash
cd ./scripts
./bootstrap.sh
```

### Локальная установка c `fish`
```bash
cd ./scripts
./bootstrap.sh --use-fish --set-login-shell fish
```

### Удалённая установка по SSH
```bash
cat ./scripts/bootstrap-remote.sh | ssh user@host 'bash -s -- --repo-url https://github.com/Ephraimus/drifter.git --repo-branch main'
```

### Windows + PowerShell
```powershell
irm https://raw.githubusercontent.com/Ephraimus/drifter/main/scripts/install-powershell.ps1 | iex
```

Подробности по Windows-сценарию: [POWERSHELL.md](POWERSHELL.md)

## Ключевые файлы

| Файл | Назначение |
| --- | --- |
| `dot_config/shell/env.list` | Общие переменные окружения |
| `dot_config/shell/aliases.sh.tmpl` | Шаблон общих alias |
| `dot_bashrc.tmpl` | Основной bash entrypoint |
| `dot_zshrc.tmpl` | Zsh bootstrap |
| `dot_config/fish/config.fish.tmpl` | Fish bootstrap |
| `~/.config/chezmoi/chezmoi.toml` | Локальные machine-specific flags |

## Обновление и синхронизация

После изменений в репозитории обновлять целевые машины можно двумя путями.

На одной машине:
```bash
chezmoi update
```

Важно: `chezmoi update` обновляет active source в `~/.local/share/chezmoi/`, а `chezmoi apply` только применяет уже существующий source к домашней директории.

На нескольких серверах:
```bash
./scripts/sync-all-remotes.sh
```

Для `sync-all-remotes.sh` нужно заполнить массив `HOSTS` и иметь SSH-доступ по ключам. Детали и расширенные сценарии описаны в [ARCHITECTURE.md](ARCHITECTURE.md).

## FAQ

<details>
<summary><b>1. Как отключить `ble.sh` на слабом сервере?</b></summary>
Отредактируйте локальный `~/.config/chezmoi/chezmoi.toml`, установите `use_blesh = false` и выполните `chezmoi apply`.
</details>

<details>
<summary><b>2. Как корректно менять alias и env?</b></summary>
Редактируйте шаблоны через `chezmoi edit`, а затем применяйте изменения через `chezmoi apply`.
</details>

<details>
<summary><b>3. Как откатить установку?</b></summary>
Запустите `./scripts/hard-reset-shell-configs.sh`, затем восстановите оригинальные файлы из `~/.shell-migration-backup/`.
</details>

## Документация

- [README.md](README.md) — быстрый старт и основные сценарии установки.
- [ARCHITECTURE.md](ARCHITECTURE.md) — внутреннее устройство, миграция, сбросы и расширенные сценарии.
- [COMMANDS.md](COMMANDS.md) — alias и shell-функции, которые ставит Drifter.
- [POWERSHELL.md](POWERSHELL.md) — Windows- и PowerShell-сценарии для этого репозитория.
- [Chezmoi Reference](https://www.chezmoi.io/) — документация `chezmoi`.
