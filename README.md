# Windows Sandbox Exe File Tester

**SandboxExeTester** is a PowerShell script that automates the process of testing executables against various access policies in a secure Windows Sandbox environment. It provides an easy-to-use GUI for selecting the executable and access policies to test, and generates detailed test results. The script accommodates executables that require user input via the command line.

![SandboxExeTester GUI](screenshots/2%20-%20host%20script.png)

## Features

- Automated testing of executables in a secure Windows Sandbox environment
- Customizable access policies to test against, including:
    - File System Access
    - Network Access
    - Clipboard Access
    - Printer Access
    - Audio Access
    - Video Input Access
    - GPU Access
- GUI for easy selection of executable and access policies
- Detailed test results including executable output, exit code, and access policy pass/fail status
- Accommodates executables that require user input via the command line
- Option to save test results to a file
- Automatic cleanup of temporary files

## Prerequisites

### Enabling Windows Sandbox

1. Open "Turn Windows features on or off"
2. Check "Windows Sandbox" and click "OK"
3. Restart your computer if prompted

### Enabling PowerShell Script Execution

1. Open PowerShell as Administrator
2. Check the current execution policy by running: `Get-ExecutionPolicy`
3. If the current policy is set to `Restricted`, change it by running: `Set-ExecutionPolicy RemoteSigned`
4. Confirm the change by typing `Y` and pressing Enter.

## Installation

1. Download the `Exe-Tester.ps1` script and save it to a directory on your system.
2. Ensure that the prerequisites are met (Windows Sandbox enabled and PowerShell script execution policy set).

## Usage

1. Open PowerShell and navigate to the directory where the script is saved.
2. Run the script by executing the following command: `.\Exe-Tester.ps1`
Alternatively, you can right-click on the script file and select "Run with PowerShell".

3. In the mode selection menu, choose option 1 to start the GUI.
4. In the GUI window, click "Browse" to select the executable file you want to test.
5. Check the boxes for the access policies you want to test against.
6. Click "Run Test" to start the testing process.

![SandboxExeTester Test Running](screenshots/4%20-%20sandbox%20after%20tests.png)

7. The script will open Windows Sandbox and execute the selected executable automatically.
8. Provide any necessary input to fully run the executable being tested.
9. After the test is complete, press Enter to close the script and Sandbox.
10. The test results will be displayed in a GUI form. You can choose to save the results to a file.

![SandboxExeTester Test Results](screenshots/6%20-%20host%20save%20results.png)

## How It Works

1. The script creates a sandbox configuration file (`SandboxConfig.wsb`) based on the user's selections, specifying the mapped folders, logon command, and networking settings for the sandbox.
2. It creates a batch file (`StartTest.cmd`) to run a PowerShell script (`RunTest.ps1`) inside the sandbox.
3. The `RunTest.ps1` script runs inside the sandbox and performs the following tasks:
- Runs the selected executable and captures its output and exit code.
- Tests the executable against the selected access policies by attempting specific actions (e.g., writing a file, accessing the network, using the clipboard).
- Logs the results of each policy test.
- Saves the test results to a JSON file (`TestResults.json`) inside the sandbox.
4. The main script waits for the sandbox test to complete by monitoring a signal file (`TestComplete.signal`) created by the `RunTest.ps1` script.
5. Once the test is complete, the main script reads the `TestResults.json` file and displays the results in a GUI form or console, depending on the user's choice.
6. The user can choose to save the test results to a file.
7. The script cleans up temporary files generated during execution.

## Understanding the Output

The test results include:
- Executable Results: Exit code and output of the executable.
- Policy Test Results: Whether each policy was passed or failed.

## Cleanup

The script automatically cleans up temporary files created during the test after each run or when exiting. If manual cleanup is needed, delete the following files from the script directory:
- `SandboxConfig.wsb`
- `SelectedPolicies.json`
- `StartTest.cmd`
- `RunTest.ps1`
- `TestResults.json`
- `TestComplete.signal`
