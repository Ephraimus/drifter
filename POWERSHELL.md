# PowerShell Support

Drifter поддерживает оба Windows-сценария:
- **PowerShell 7+ (`pwsh`)**
- **Windows PowerShell 5.1**

Установка в обоих случаях идёт через `Scoop` + `chezmoi`. Репозиторий разворачивает оба профиля:
- `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

## Быстрый старт

### One-command установка из удалённого репозитория
```powershell
irm https://raw.githubusercontent.com/Ephraimus/chezmoi/main/scripts/install-powershell.ps1 | iex
```

### Локальный репозиторий
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
.\scripts\bootstrap-powershell.ps1
```

### Установка из Git-репозитория
```powershell
.\scripts\bootstrap-powershell.ps1 -RepoUrl https://github.com/Ephraimus/chezmoi.git -RepoBranch main
```

## Что делает установка

- Ставит `git`, `chezmoi`, `starship`, `zoxide`, `eza`, `bat`, `fzf`, `fd`, `ripgrep` через `Scoop`.
- Ставит модуль `PSFzf` для `Ctrl+T` и `Ctrl+R`.
- Сохраняет существующий профиль текущего PowerShell в `Microsoft.PowerShell_profile.legacy.ps1`.
- Применяет конфиги через `chezmoi`, а не копирует шаблоны вручную.
- Если `chezmoi` уже был инициализирован раньше, bootstrap обновляет существующий source через `chezmoi update --init`, чтобы не оставаться на старой локальной версии репозитория.

## Проверка установки

### 1. Проверить версию текущего PowerShell
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

### 4. Проверить алиасы и функции
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

### 6. Проверить старый профиль
```powershell
$profileDir = Split-Path -Parent $PROFILE
Get-ChildItem $profileDir
```

Если профиль существовал до установки, рядом должен лежать:
```text
Microsoft.PowerShell_profile.legacy.ps1
```

## Какие файлы управляются

- `scripts/install-powershell.ps1`
- `scripts/bootstrap-powershell.ps1`
- `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`
- `Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1.tmpl`

## Примечания

- Если открыто старое окно PowerShell, после установки лучше открыть новую сессию.
- Для Windows Terminal рекомендуется сделать `PowerShell 7` профилем по умолчанию, но Windows PowerShell 5.1 тоже поддерживается.
