[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

$scheme_name = 'Zed One Dark'
$source_path = Join-Path $PSScriptRoot 'zed_one_dark.json'
$target_root = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\zcmd'
$target_path = Join-Path $target_root 'zed_one_dark.json'

$fragment_roots = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments'),
    (Join-Path $env:ProgramData 'Microsoft\Windows Terminal\Fragments')
)

$settings_paths = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
)

$scheme_keys = @(
    'name',
    'background',
    'black',
    'red',
    'green',
    'yellow',
    'blue',
    'purple',
    'cyan',
    'white',
    'brightBlack',
    'brightRed',
    'brightGreen',
    'brightYellow',
    'brightBlue',
    'brightPurple',
    'brightCyan',
    'brightWhite',
    'foreground',
    'selectionBackground',
    'cursorColor'
)

function scheme_normalize($scheme) {
    $ordered = [ordered]@{}

    foreach ($key in $scheme_keys) {
        if ($null -ne $scheme.$key) {
            $ordered[$key] = [string]$scheme.$key
        }
    }

    return ($ordered | ConvertTo-Json -Compress)
}

function json_load($path) {
    $raw = Get-Content -LiteralPath $path -Raw
    return $raw | ConvertFrom-Json
}

function scheme_from_file($path) {
    $doc = json_load $path

    if ($null -eq $doc.schemes) {
        return $null
    }

    foreach ($scheme in @($doc.schemes)) {
        if ($scheme.name -eq $scheme_name) {
            return $scheme
        }
    }

    return $null
}

if (-not (Test-Path -LiteralPath $source_path)) {
    throw "Theme source file not found: $source_path"
}

$desired_scheme = scheme_from_file $source_path

if ($null -eq $desired_scheme) {
    throw "Theme source file does not contain a '$scheme_name' scheme: $source_path"
}

$desired_scheme_json = scheme_normalize $desired_scheme

foreach ($settings_path in $settings_paths) {
    if (-not (Test-Path -LiteralPath $settings_path)) {
        continue
    }

    try {
        $existing_scheme = scheme_from_file $settings_path
    } catch {
        Write-Warning "Skipping unreadable settings file: $settings_path"
        continue
    }

    if ($null -eq $existing_scheme) {
        continue
    }

    $existing_scheme_json = scheme_normalize $existing_scheme

    if ($existing_scheme_json -eq $desired_scheme_json) {
        Write-Output "Theme already present in settings: $settings_path"
        exit 0
    }

    throw "A different '$scheme_name' scheme already exists in settings: $settings_path"
}

foreach ($fragment_root in $fragment_roots) {
    if (-not (Test-Path -LiteralPath $fragment_root)) {
        continue
    }

    $fragment_files = Get-ChildItem -LiteralPath $fragment_root -Recurse -Filter *.json -File -ErrorAction SilentlyContinue

    foreach ($fragment_file in $fragment_files) {
        try {
            $existing_scheme = scheme_from_file $fragment_file.FullName
        } catch {
            continue
        }

        if ($null -eq $existing_scheme) {
            continue
        }

        $existing_scheme_json = scheme_normalize $existing_scheme

        if ($existing_scheme_json -eq $desired_scheme_json) {
            Write-Output "Theme already installed via fragment: $($fragment_file.FullName)"
            exit 0
        }

        throw "A different '$scheme_name' scheme already exists in fragment: $($fragment_file.FullName)"
    }
}

if (-not (Test-Path -LiteralPath $target_root)) {
    if ($PSCmdlet.ShouldProcess($target_root, 'Create Windows Terminal fragment directory')) {
        New-Item -ItemType Directory -Path $target_root -Force | Out-Null
    }
}

if ($PSCmdlet.ShouldProcess($target_path, 'Install Windows Terminal theme fragment')) {
    Get-Content -LiteralPath $source_path -Raw | Out-File -LiteralPath $target_path -Encoding utf8
}

Write-Output "Installed '$scheme_name' to $target_path"
