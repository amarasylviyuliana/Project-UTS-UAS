(Get-Content $args[0]) -replace "^pick c160df3", "edit c160df3" | Set-Content $args[0]
