<#
.SYNOPSIS
Sandbox Policy Checker and Executable Testing Tool
.DESCRIPTION
This script tests executables in a Windows Sandbox environment for various access policies.
It automates the process of creating a sandbox, running tests, and retrieving results.
#>

# GUI elements
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Access Policies
$accessPolicies = @{
    "Network Access"     = $false
    "File System Access" = $false
    "Clipboard Access"   = $false
    "Printer Access"     = $false
    "Audio Access"       = $false
    "Video Input Access" = $false
    "GPU Access"         = $false
}

# PS Window Prompts
function Show-ModeSelection {
    Clear-Host
    Write-Host "Sandbox Executable Testing Tool" -ForegroundColor Green
    Write-Host "This tool tests executables against various access policies in a Windows Sandbox environment." -ForegroundColor Green
    Write-Host ""
    Write-Host "1. Start the GUI"
    Write-Host "2. Exit"
    $choice = Read-Host "Please select an option (1-2)"
    return $choice
}

# Fn to get user selections via the GUI form
function Get-UserSelections {
    $selections = @{}
    $selections["Policies"] = @{}
    
    # Main Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Access Policies and Executable"
    $form.Size = New-Object System.Drawing.Size(400, 550)

    # Select EXE file
    $fileLabel = New-Object System.Windows.Forms.Label
    $fileLabel.Location = New-Object System.Drawing.Point(10, 10)
    $fileLabel.Size = New-Object System.Drawing.Size(350, 20)
    $fileLabel.Text = "Select executable to test:"
    $form.Controls.Add($fileLabel)

    # Display EXE path
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10, 40)
    $textBox.Size = New-Object System.Drawing.Size(280, 20)
    $form.Controls.Add($textBox)

    # File browsing for selection of EXE
    $browseButton = New-Object System.Windows.Forms.Button
    $browseButton.Location = New-Object System.Drawing.Point(300, 38)
    $browseButton.Size = New-Object System.Drawing.Size(75, 23)
    $browseButton.Text = "Browse"
    $browseButton.Add_Click({
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "Executable Files (*.exe)|*.exe"
            $openFileDialog.InitialDirectory = $PSScriptRoot
            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $textBox.Text = [System.IO.Path]::GetFileNameWithoutExtension($openFileDialog.FileName)
            }
        })
    $form.Controls.Add($browseButton)

    # Selecting access policies
    $policyLabel = New-Object System.Windows.Forms.Label
    $policyLabel.Location = New-Object System.Drawing.Point(10, 70)
    $policyLabel.Size = New-Object System.Drawing.Size(350, 20)
    $policyLabel.Text = "Select the access policies to test against:"
    $form.Controls.Add($policyLabel)

    # Checkboxes
    $y = 100
    foreach ($policy in $accessPolicies.Keys) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Location = New-Object System.Drawing.Point(10, $y)
        $checkbox.Size = New-Object System.Drawing.Size(350, 20)
        $checkbox.Text = $policy
        $checkbox.Checked = $false
        $form.Controls.Add($checkbox)
        $y += 30
    }

    # Run Test
    $runButton = New-Object System.Windows.Forms.Button
    $runButton.Location = New-Object System.Drawing.Point(150, $y)
    $runButton.Size = New-Object System.Drawing.Size(75, 23)
    $runButton.Text = "Run Test"
    $runButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $runButton
    $form.Controls.Add($runButton)

    # Display the form and capture user input
    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($control in $form.Controls) {
            if ($control -is [System.Windows.Forms.CheckBox]) {
                $selections["Policies"][$control.Text] = $control.Checked
            }
        }
        $selections["ExePath"] = Join-Path $PSScriptRoot "$($textBox.Text).exe"
    }
    else {
        return $null
    }

    return $selections
}

# Fn to create the sandbox config file
function Create-SandboxConfiguration {
    param (
        [string]$ExePath,
        [hashtable]$Policies
    )
    $sandboxConfig = @"
<Configuration>
    <MappedFolders>
        <MappedFolder>
            <HostFolder>$PSScriptRoot</HostFolder>
            <SandboxFolder>C:\Sandbox</SandboxFolder>
            <ReadOnly>false</ReadOnly>
        </MappedFolder>
    </MappedFolders>
    <LogonCommand>
        <Command>C:\Sandbox\StartTest.cmd</Command>
    </LogonCommand>
    <Networking>Default</Networking>
</Configuration>
"@
    $sandboxConfig | Out-File -FilePath ".\SandboxConfig.wsb" -Encoding utf8

    # Save selected policies to a file
    $Policies | ConvertTo-Json | Out-File -FilePath ".\SelectedPolicies.json" -Encoding utf8

    # Create a batch file to run the PS script in the sandbox
    $batchFile = @"
@echo off
start powershell -NoExit -ExecutionPolicy Bypass -File C:\Sandbox\RunTest.ps1 -ExePath "$([System.IO.Path]::GetFileName($ExePath))"
"@
    $batchFile | Out-File -FilePath ".\StartTest.cmd" -Encoding ascii
}

# Fn to create the test script that will run inside the sandbox
function Create-TestScript {
    $testScript = @'
param (
    [string]$ExePath
)

$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'

# Read selected policies from the file
$PolicyHash = Get-Content -Path "C:\Sandbox\SelectedPolicies.json" -Raw | ConvertFrom-Json

# Initialize results with "Not Tested" for selected policies and "Skipped" for others
$results = @{
    "File System Access" = if ($PolicyHash."File System Access") { "Not Tested" } else { "Skipped" }
    "Network Access" = if ($PolicyHash."Network Access") { "Not Tested" } else { "Skipped" }
    "Clipboard Access" = if ($PolicyHash."Clipboard Access") { "Not Tested" } else { "Skipped" }
    "Printer Access" = if ($PolicyHash."Printer Access") { "Not Tested" } else { "Skipped" }
    "Audio Access" = if ($PolicyHash."Audio Access") { "Not Tested" } else { "Skipped" }
    "Video Input Access" = if ($PolicyHash."Video Input Access") { "Not Tested" } else { "Skipped" }
    "GPU Access" = if ($PolicyHash."GPU Access") { "Not Tested" } else { "Skipped" }
}

# Function to test each policy
function Test-Policy {
    param (
        [string]$PolicyName,
        [scriptblock]$TestScript
    )
    if ($PolicyHash.$PolicyName) {
        Write-Host ("Testing " + $PolicyName + "...") -ForegroundColor Cyan
        try {
            $result = & $TestScript
            $script:results[$PolicyName] = $result
            Write-Host ($PolicyName + ": " + $result) -ForegroundColor $(if ($result -eq "Passed") { "Green" } else { "Red" })
        }
        catch {
            $script:results[$PolicyName] = "Error: " + $_.Exception.Message
            Write-Host ($PolicyName + ": Error - " + $_.Exception.Message) -ForegroundColor Red
        }
    }
}

Write-Host ("Starting tests for " + $ExePath + "...") -ForegroundColor Green

# Run the executable and capture its output
Write-Host "Running the executable and testing access..." -ForegroundColor Cyan
try {
    $exePath = "C:\Sandbox\" + $ExePath
    Write-Host ("Executable path: " + $exePath) -ForegroundColor Cyan
    if (Test-Path $exePath) {
        Write-Host "Executable file exists. Running and monitoring access..." -ForegroundColor Green
        $process = Start-Process -FilePath $exePath -NoNewWindow -PassThru

        Write-Host "Executable is running. You can interact with it below:" -ForegroundColor Yellow
        Write-Host "Press Ctrl+C when you're done to continue with the tests." -ForegroundColor Yellow

        try {
            while (-not $process.HasExited) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq "Enter") {
                        [Console]::WriteLine()
                    } else {
                        [Console]::Write($key.KeyChar)
                    }
                }
                Start-Sleep -Milliseconds 100
            }
        }
        catch [System.Management.Automation.PSInvalidOperationException] {
            # Ctrl+C was pressed
            if (-not $process.HasExited) {
                $process.CloseMainWindow()
                Start-Sleep -Seconds 5
                if (-not $process.HasExited) {
                    $process.Kill()
                }
            }
        }

        $script:results["Executable Exit Code"] = $process.ExitCode
        Write-Host ("Executable ran with exit code: " + $process.ExitCode) -ForegroundColor Green
        
        # Capture output from file
        $stdoutPath = "C:\Sandbox\stdout.txt"
        $stderrPath = "C:\Sandbox\stderr.txt"
        $stdout = if (Test-Path $stdoutPath) { Get-Content $stdoutPath -Raw } else { "" }
        $stderr = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { "" }
        
        $script:results["Executable Output"] = "StdOut: " + $stdout + "`nStdErr: " + $stderr
        Write-Host "Executable Output:" -ForegroundColor Green
        Write-Host $script:results["Executable Output"]
    } else {
        Write-Host ("Executable file not found at " + $exePath) -ForegroundColor Red
        $script:results["Executable Output"] = "File not found"
    }
} catch {
    $script:results["Executable Output"] = "Failed to run executable: " + $_.Exception.Message
    Write-Host ("Failed to run executable: " + $_.Exception.Message) -ForegroundColor Red
}

# Now run the policy tests
Write-Host "Running policy tests..." -ForegroundColor Cyan

# File System Access Test
Test-Policy "File System Access" {
    try {
        [System.IO.File]::Create("C:\TestWrite.txt").Close()
        return "Failed (Write successful)"
    } catch {
        return "Passed (Write blocked)"
    }
}

# Network Access Test
Test-Policy "Network Access" {
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadString("http://www.example.com") | Out-Null
        return "Failed (Network access successful)"
    } catch {
        return "Passed (Network access blocked)"
    }
}

# Clipboard Access Test
Test-Policy "Clipboard Access" {
    try {
        Set-Clipboard -Value "Test"
        $clipboardContent = Get-Clipboard
        if ($clipboardContent -eq "Test") {
            return "Failed (Clipboard access successful)"
        } else {
            return "Passed (Clipboard access blocked)"
        }
    } catch {
        return "Passed (Clipboard access blocked)"
    }
}

# Printer Access Test
Test-Policy "Printer Access" {
    $printers = Get-Printer
    if ($printers) {
        return "Failed (Printers available)"
    } else {
        return "Passed (No printers available)"
    }
}

# Audio Access Test
Test-Policy "Audio Access" {
    $audioDevices = Get-WmiObject Win32_SoundDevice
    if ($audioDevices) {
        return "Failed (Audio devices available)"
    } else {
        return "Passed (No audio devices available)"
    }
}

# Video Input Access Test
Test-Policy "Video Input Access" {
    $videoDevices = Get-WmiObject Win32_PnPEntity | Where-Object { $_.PNPClass -eq "Image" }
    if ($videoDevices) {
        return "Failed (Video devices available)"
    } else {
        return "Passed (No video devices available)"
    }
}

# GPU Access Test
Test-Policy "GPU Access" {
    $gpuDevices = Get-WmiObject Win32_VideoController | Where-Object { $_.AdapterDACType -ne "Internal" }
    if ($gpuDevices) {
        return "Failed (GPU devices available)"
    } else {
        return "Passed (No GPU devices available)"
    }
}

# Display results in the Sandbox PowerShell window
Write-Host "`nTest Results:" -ForegroundColor Cyan
Write-Host "Executable Results:"
Write-Host "Exit Code: $($results['Executable Exit Code'])"
Write-Host "Output: $($results['Executable Output'])"
Write-Host "`nPolicy Test Results:"
foreach ($policy in $results.Keys) {
    Write-Host "$policy : $($results[$policy])"
}

# Save results to a file
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath "C:\Sandbox\TestResults.json"
Write-Host "All tests completed. Results saved to TestResults.json" -ForegroundColor Green
Write-Host "Results will be sent back to the host script."

# Ask the user to press Enter to close the window
Write-Host "Press Enter to close this window and the sandbox..."
$null = Read-Host

# Signal that the test is complete
New-Item -Path "C:\Sandbox\TestComplete.signal" -ItemType File
'@
   $testScript | Out-File -FilePath ".\RunTest.ps1" -Encoding utf8
}

# Fn to run the sandbox test
function Run-SandboxTest {
    param (
        [string]$ExePath,
        [hashtable]$Policies
    )
    # Create sandbox config and scripts
    Create-SandboxConfiguration -ExePath $ExePath -Policies $Policies
    Create-TestScript

    # Run the sandbox
    Write-Host "Launching Windows Sandbox and running tests. Please wait..." -ForegroundColor Cyan
    $sandboxProcess = Start-Process "C:\Windows\System32\WindowsSandbox.exe" -ArgumentList ".\SandboxConfig.wsb" -PassThru

    # Wait for the test to complete
    $testCompletePath = Join-Path $PSScriptRoot "TestComplete.signal"
    while (-not (Test-Path $testCompletePath)) {
        Start-Sleep -Seconds 1
    }

    # Read and parse results
    $resultsPath = Join-Path $PSScriptRoot "TestResults.json"
    if (Test-Path $resultsPath) {
        $results = Get-Content $resultsPath -Raw | ConvertFrom-Json
    
        # Convert results to hashtable
        $resultsHash = @{}
        $results.PSObject.Properties | ForEach-Object { $resultsHash[$_.Name] = $_.Value }
    
        # Close the sandbox
        Stop-Process -Id $sandboxProcess.Id -Force
    
        return $resultsHash
    }
    else {
        Write-Host "Error: Test results not found." -ForegroundColor Red
        return $null
    }
}

# Fn to display results in GUI or console mode
function Display-Results {
    param (
        [hashtable]$Results,
        [bool]$IsGui
    )
    if ($IsGui) {
        # Display results in a GUI form
        $resultForm = New-Object System.Windows.Forms.Form
        $resultForm.Text = "Test Results"
        $resultForm.Size = New-Object System.Drawing.Size(500, 400)
        $resultBox = New-Object System.Windows.Forms.TextBox
        $resultBox.Multiline = $true
        $resultBox.ScrollBars = "Vertical"
        $resultBox.Dock = "Fill"
        
        $resultText = "Executable Results:`r`n"
        $resultText += "Exit Code: $($Results['Executable Exit Code'])`r`n"
        $resultText += "Output: $($Results['Executable Output'])`r`n`r`n"
        $resultText += "Policy Test Results:`r`n"
        foreach ($key in $Results.Keys) {
            if ($key -notin @('Executable Exit Code', 'Executable Output')) {
                $resultText += "$key : $($Results[$key])`r`n"
            }
        }
        $resultBox.Text = $resultText
        
        $resultForm.Controls.Add($resultBox)
    
        $saveButton = New-Object System.Windows.Forms.Button
        $saveButton.Text = "Save Results"
        $saveButton.Dock = "Bottom"
        $saveButton.Add_Click({
                $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
                $saveFileDialog.Filter = "Text Files (*.txt)|*.txt"
                $saveFileDialog.FileName = "TestResults.txt"
                if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $resultBox.Text | Out-File $saveFileDialog.FileName
                    [System.Windows.Forms.MessageBox]::Show("Results saved successfully.", "Save", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                }
            })
        $resultForm.Controls.Add($saveButton)
    
        $resultForm.ShowDialog()
    }
    else {
        # Display results in the console
        Write-Host "`nTest Results:" -ForegroundColor Cyan
        Write-Host "Executable Results:"
        Write-Host "Exit Code: $($Results['Executable Exit Code'])"
        Write-Host "Output: $($Results['Executable Output'])"
        Write-Host "`nPolicy Test Results:"
        foreach ($key in $Results.Keys) {
            if ($key -notin @('Executable Exit Code', 'Executable Output')) {
                Write-Host "$key : $($Results[$key])"
            }
        }
    
        $saveChoice = Read-Host "`nDo you want to save the results to a file? (Y/N)"
        if ($saveChoice -eq "Y") {
            $resultsPath = Read-Host "Enter the path to save the results file"
            $Results | Out-File $resultsPath
            Write-Host "Results saved to $resultsPath" -ForegroundColor Green
        }
    }
}

# Fn to clean up temporary files generated during script execution
function Cleanup-TempFiles {
    $tempFiles = @(".\SandboxConfig.wsb", ".\SelectedPolicies.json", ".\StartTest.cmd", ".\RunTest.ps1", ".\TestResults.json", ".\TestComplete.signal")
    foreach ($file in $tempFiles) {
        if (Test-Path $file) {
            Remove-Item -Path $file -Force
        }
    }
    Write-Host "Temporary files cleaned up." -ForegroundColor Green
}

# Main execution function
function Main {
    do {
        $mode = Show-ModeSelection
        switch ($mode) {
            "1" {
                $selections = Get-UserSelections
                if ($selections -ne $null) {
                    Write-Host "Running test in Windows Sandbox. Please wait..."
                    $results = Run-SandboxTest -ExePath $selections["ExePath"] -Policies $selections["Policies"]
                    if ($results -ne $null) {
                        Display-Results -Results $results -IsGui $true
                    }
                    Cleanup-TempFiles # Clean up temporary files after the test
                }
            }
            "2" {
                Write-Host "Exiting..."
                Cleanup-TempFiles # Clean up temporary files before exiting
                exit
            }
            default {
                Write-Host "Invalid selection. Please try again." -ForegroundColor Yellow
                continue
            }
        }
        $rerun = Read-Host "`nDo you want to run another test? (Y/N)"
    } while ($rerun -eq "Y")
}

# Start the script
Main
