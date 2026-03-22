# Поддержка PowerShell

Drifter поддерживает оба Windows-сценария:

- **PowerShell 7+ (`pwsh`)**
- **Windows PowerShell 5.1**

Этот документ описывает только Windows- и PowerShell-сценарии самого `drifter`.
Общий обзор проекта находится в [README.md](README.md).

Установка идёт через `Scoop` + `chezmoi`. Репозиторий разворачивает оба профиля:

- `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

## Быстрый старт для Windows

### Установка одной командой из удалённого репозитория
```powershell
irm https://raw.githubusercontent.com/Ephraimus/drifter/main/scripts/install-powershell.ps1 | iex
```

### Установка из локального репозитория
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\scripts\bootstrap-powershell.ps1
```

### Установка из Git-репозитория
```powershell
.\scripts\bootstrap-powershell.ps1 -RepoUrl https://github.com/Ephraimus/drifter.git -RepoBranch main
```

## Что делает установка

- Устанавливает `git`, `chezmoi`, `starship`, `zoxide`, `eza`, `bat`, `fzf`, `fd`, `ripgrep` через `Scoop`.
- Устанавливает модуль `PSFzf` для `Ctrl+T` и `Ctrl+R`.
- Сохраняет существующий профиль в `Microsoft.PowerShell_profile.legacy.ps1`.
- Применяет конфиги через `chezmoi`, а не копирует шаблоны вручную.
- Если `chezmoi` уже был инициализирован раньше, bootstrap обновляет existing source через `chezmoi update --init`.
- Добавляет `%USERPROFILE%\scoop\shims` в `PATH` на уровне профиля.

## Проверка установки

### 1. Проверить версию PowerShell
```powershell
$PSVersionTable
```

Ожидаемо:

- `PSEdition = Core` для `pwsh`
- `PSEdition = Desktop` для Windows PowerShell 5.1

### 2. Проверить, что профиль существует
```powershell
$PROFILE
Test-Path $PROFILE
Get-Content $PROFILE
```

### 3. Проверить установленные инструменты
```powershell
Get-Command chezmoi, starship, zoxide, eza, bat, fzf, git
Get-Module -ListAvailable PSFzf
```

### 4. Проверить alias и функции
```powershell
Get-Command gs, ga, gc, gp, gl, ll, la, mkd, c
```

### 5. Проверить поведение в сессии
```powershell
gs
ll
la
mkd test-dir
z ..
```

### 6. Проверить legacy-профиль
```powershell
$profileDir = Split-Path -Parent $PROFILE
Get-ChildItem $profileDir
```

Если профиль существовал до установки, рядом должен лежать:

```text
Microsoft.PowerShell_profile.legacy.ps1
```

## Какие файлы используются

- `scripts/install-powershell.ps1`
- `scripts/bootstrap-powershell.ps1`
- `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`
- `Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1.tmpl`

## Примечания

- После установки лучше открыть новую сессию PowerShell.
- В PowerShell имена `gc`, `gp` и `gl` по умолчанию уже заняты встроенными alias (`Get-Content`, `Get-ItemProperty`, `Get-Location`). Профиль Drifter сначала удаляет эти alias, а затем объявляет одноимённые git-функции.
