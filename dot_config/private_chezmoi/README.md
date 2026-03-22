Local chezmoi data should live on each machine in:

  ~/.config/chezmoi/chezmoi.toml

Do not manage that file from the shared repo. Use examples/chezmoi.local.example.toml as a starting point.
For Windows / PowerShell 7+ hosts, keep `use_powershell = true` in that local file.
