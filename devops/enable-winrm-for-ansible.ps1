<#
    One-time WinRM bootstrap so Ansible can manage this Windows host.

    Run once per machine, locally, in an ELEVATED PowerShell
    ("Run as Administrator"). There is no SSH key involved - Windows hosts
    authenticate with username + password over NTLM.

    Connection model this sets up (matches inventory/group_vars/windows.yml):
        ansible_connection: winrm
        ansible_port: 5985            (HTTP; NTLM encrypts the payload itself)
        ansible_winrm_transport: ntlm

    Check afterwards from the control node:
        ansible -i inventory/hosts.yml <host> -m ansible.windows.win_ping
#>

$ErrorActionPreference = 'Stop'

# --- adjust these two -------------------------------------------------------
$AnsibleUser = 'asaroot'                     # local admin account Ansible uses
$ControlNode = 'ansible-oca.oca.lan'                   # ansible-oca.oca.lan - PUT THE REAL IP HERE
# ---------------------------------------------------------------------------

Write-Host "1/6 Enabling PowerShell remoting / WinRM service..." -ForegroundColor Cyan
Enable-PSRemoting -Force -SkipNetworkProfileCheck

Write-Host "2/6 Hardening the WinRM service config..." -ForegroundColor Cyan
# Keep message-level encryption on. Basic auth stays off; Negotiate covers NTLM.
winrm set winrm/config/service      '@{AllowUnencrypted="false"}'      | Out-Null
winrm set winrm/config/service/auth '@{Basic="false";Negotiate="true"}' | Out-Null

Write-Host "3/6 Raising the shell memory limit (some modules need it)..." -ForegroundColor Cyan
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}' | Out-Null

Write-Host "4/6 Restricting inbound WinRM to the control node..." -ForegroundColor Cyan
# Rule names differ between Windows versions, so match by display group.
Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' |
    Where-Object { $_.Direction -eq 'Inbound' } |
    Set-NetFirewallRule -Enabled True -RemoteAddress $ControlNode

Write-Host "5/6 Allowing network logon for non-builtin local admins..." -ForegroundColor Cyan
# Without this, a local admin account that is not the built-in "Administrator"
# gets a filtered token over the network and every task fails with access denied.
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
                 -Name 'LocalAccountTokenFilterPolicy' -Value 1 -PropertyType DWord -Force | Out-Null

Write-Host "6/6 Checking the Ansible account..." -ForegroundColor Cyan
$isAdmin = Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -like "*\$AnsibleUser" }
if (-not $isAdmin) {
    Write-Warning "'$AnsibleUser' is NOT in the local Administrators group. Add it before running Ansible:"
    Write-Warning "  net localgroup Administrators $AnsibleUser /add"
} else {
    Write-Host "  '$AnsibleUser' is a local administrator - good." -ForegroundColor Green
}

Write-Host "`nActive WinRM listeners:" -ForegroundColor Cyan
winrm enumerate winrm/config/listener
