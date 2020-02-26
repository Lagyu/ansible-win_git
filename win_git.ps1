#!powershell

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# Copyright: (c) 2020, Yuya Sasaki <sasaki.y@ruri.waseda.jp>
# Original authors: Anatoliy Ivashina <tivrobo@gmail.com>, Pablo Estigarribia <pablodav@gmail.com>, Michael Hay <project.hay@gmail.com>


#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        repo = @{ type = "str"; required = $true }
        dest = @{ type = "str"; required = $true }
        branch = @{ type = "str"; default = "master" }
        clone = @{ type = "str" }
        update = @{ type = "str" }
        recursive = @{ type = "str" }
        replace_dest = @{ type = "str" }
        accept_hostkey = @{ type = "str" }
        key_file = @{ type = "str" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$repo  = $module.Params.repo
$dest  = $module.Params.dest
$branch = $module.Params.branch
$clone  = $module.Params.clone
$update = $module.Params.update
$recursive = $module.Params.recursive
$replace_dest = $module.Params.replace_dest
$accept_hostkey = $module.Params.accept_hostkey
$key_file = $module.Params.key_file

$module.Result.win_git = @{
    repo           = $null
    dest           = $null
    clone          = $false
    replace_dest   = $true
    accept_hostkey = $true
    update         = $false
    recursive      = $true
    branch         = "master"
    key_file       = $null
    ssh_command    = $null
}
$module.Result.changed = $false
$module.Result.cmd_msg = $null

# Add Git to PATH variable
# Test with git 2.14
$env:Path += ";" + "C:\Program Files\Git\bin"
$env:Path += ";" + "C:\Program Files\Git\usr\bin"
$env:Path += ";" + "C:\Program Files (x86)\Git\bin"
$env:Path += ";" + "C:\Program Files (x86)\Git\usr\bin"

# Functions
function Find-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [string] $command
    )
    $installed = get-command $command -erroraction Ignore
    write-verbose "$installed"
    if ($installed) {
        return $installed
    }
    return $null
}

function FindGit {
    [CmdletBinding()]
    param()
    $p = Find-Command "git.exe"
    if ($p -ne $null) {
        return $p
    }
    $a = Find-Command "C:\Program Files\Git\bin\git.exe"
    if ($a -ne $null) {
        return $a
    }
    $module.FailJson("git.exe is not installed. It must be installed (use chocolatey)")
}

# Remove dest if it exests
function PrepareDestination {
    [CmdletBinding()]
    param()
    if ((Test-Path $dest) -And (-Not $check_mode)) {
        try {
            Remove-Item $dest -Force -Recurse | Out-Null
            $module.Result.cmd_msg = "Successfully removed dir $dest."
            $module.Result.changed = $true
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $module.FailJson("Error removing $dest! Msg: $ErrorMessage")
        }
    }
}

# SSH Keys
function CheckSshKnownHosts {
    [CmdletBinding()]
    param()
    # Get the Git Hostrepo
    $gitServer = $($repo -replace "^(\w+)\@([\w-_\.]+)\:(.*)$", '$2')
    ssh-keygen -F $gitServer
}

function AddToKnownHosts {
    [CmdletBinding()]
    param()
    # Get the Git Hostrepo
    $gitServer = $($repo -replace "^(\w+)\@([\w-_\.]+)\:(.*)$", '$2')
    if ($accept_hostkey) {
        $known_hosts_file_path = $env:USERPROFILE + "\.ssh\known_hosts"
        Start-Process -FilePath "cmd" -ArgumentList "/c", "ssh-keyscan", "-t", "ssh-rsa", $gitServer, ">>", $known_hosts_file_path -Wait
    }
    else {
        $module.FailJson("Host is not registered in known_host file!")
    }
}

function CheckSshIdentity {
    [CmdletBinding()]
    param()

    $gitServer = $($repo -replace "^(\w+)\@([\w-_\.]+)\:(.*)$", '$2')
    try {
        git.exe ls-remote $repo | Out-Null
        $rc = $LASTEXITCODE
    }
    catch {
        $rc = $LASTEXITCODE
    }
    if ($rc -ne 0) {
        if ($null -ne $key_file) {
            if ([System.IO.File]::Exists($key_file)) {
                $env:GIT_SSH_COMMAND='ssh -o IdentitiesOnly=yes -i "' + $key_file + '"'
                $module.Result.win_git.key_file = $key_file
                $module.Result.win_git.ssh_command = $env:GIT_SSH_COMMAND
            }
            else {
                $module.Result.win_git.key_file = "Error: File not found."
                $module.FailJson("No such private key file: " + $key_file)
            }
        }
        else {
            $module.FailJson("You don't have access to repo. Please setup ssh key or specify the path to key_file parameter.(there may be other problems)")
        }
        try {
            git.exe ls-remote $repo | Out-Null
            $rc = $LASTEXITCODE
        }
        catch {
            $rc = $LASTEXITCODE
        }
        if ($rc -ne 0) {
            $module.FailJson("You don't have access to repo, even with the key specified! (there may be other problems)")
        }
    }
}

function get_version {
    # samples the version of the git repo
    # example:  git rev-parse HEAD
    #           output: 931ec5d25bff48052afae405d600964efd5fd3da
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)] [string] $refs = "HEAD"
    )
    $git_opts = @()
    $git_opts += "--no-pager"
    $git_opts += "rev-parse"
    $git_opts += "$refs"
    $git_cmd_output = ""

    [hashtable]$Return = @{}
    Set-Location $dest; git $git_opts | Tee-Object -Variable git_cmd_output | Out-Null
    $Return.rc = $LASTEXITCODE
    $Return.git_output = $git_cmd_output

    return $Return
}

function checkout {
    [CmdletBinding()]
    param()
    [hashtable]$Return = @{}
    $local_git_output = ""

    $git_opts = @()
    $git_opts += "--no-pager"
    $git_opts += "checkout"
    $git_opts += "$branch"
    Set-Location $dest; git $git_opts | Tee-Object -Variable local_git_output | Out-Null

    $Return.git_output = $local_git_output
    Set-Location $dest; git status --short --branch | Tee-Object -Variable branch_status | Out-Null
    $branch_status = $branch_status.split("/")[1]
    $module.Result.win_git.branch_status = "$branch_status"

    if ( $branch_status -ne "$branch" ) {
        $module.FailJson("Failed to checkout to $branch")
    }

    return $Return
}

function clone {
    # git clone command
    [CmdletBinding()]
    param()

    $module.Result.win_git.method = "clone"
    [hashtable]$Return = @{}
    $local_git_output = ""

    $git_opts = @()
    $git_opts += "--no-pager"
    $git_opts += "clone"
    $git_opts += $repo
    $git_opts += $dest
    $git_opts += "--branch"
    $git_opts += $branch
    if ($recursive) {
        $git_opts += "--recursive"
    }

    $module.Result.win_git.git_opts = "$git_opts"

    #Only clone if $dest does not exist and not in check mode
    if ( (-Not (Test-Path -Path $dest)) -And (-Not $check_mode)) {
        try {
            git $git_opts
            $Return.rc = $LASTEXITCODE
        }
        catch {
            $Return.rc = $LASTEXITCODE
        }
        $Return.git_output = $local_git_output
        $module.Result.cmd_msg = "Successfully cloned $repo into $dest."
        $module.Result.changed = $true
        $module.Result.win_git.return_code = $LASTEXITCODE
        $module.Result.win_git.git_output = $local_git_output
    }
    else {
        $Return.rc = 0
        $Return.git_output = $local_git_output
        $module.Result.cmd_msg = "Skipping Clone of $repo becuase $dest already exists"
    }

    # Check if branch is the correct one
    Set-Location $dest; git status --short --branch | Tee-Object -Variable branch_status | Out-Null
    $branch_status = $branch_status.split("/")[1]
    $module.Result.win_git.branch_status = "$branch_status"

    if ( $branch_status -ne "$branch" ) {
        $module.FailJson("Branch $branch_status is not $branch")
    }

    return $Return
}

function update {
    # git clone command
    [CmdletBinding()]
    param()

    $module.Result.win_git.method = "pull"
    [hashtable]$Return = @{}
    $git_output = ""

    # Build Arguments
    $git_opts = @()
    $git_opts += "--no-pager"
    $git_opts += "pull"
    $git_opts += "origin"
    $git_opts += "$branch"

    $module.Result.win_git.git_opts = "$git_opts"
    #Only update if $dest does exist and not in check mode
    if ((Test-Path -Path $dest) -and (-Not $check_mode)) {
        
        $current_brunch = git symbolic-ref --short HEAD
        if ($current_brunch -ne $branch) {
        # move into correct branch before pull
        checkout
        }
        # perform git pull
        try {        
            Set-Location $dest; git $git_opts | Tee-Object -Variable git_output | Out-Null    
            $Return.rc = $LASTEXITCODE
            $Return.git_output = $git_output
            $module.Result.cmd_msg = "Successfully updated $repo to $branch."
            #TODO: handle correct status change when using update
            $module.Result.changed = $true
            $module.Result.win_git.return_code = $LASTEXITCODE
            $module.Result.win_git.git_output = $git_output
        }
        catch {
            # pass
        }
    }
    else {
        $Return.rc = 0
        $Return.git_output = $local_git_output
        $module.Result.cmd_msg = "Skipping update of $repo"
    }

    return $Return
}


if ($repo -eq ($null -or "")) {
    $module.FailJson("Repository cannot be empty or `$null")
}
$module.Result.win_git.repo = $repo
$module.Result.win_git.dest = $dest

$module.Result.win_git.replace_dest = $replace_dest
$module.Result.win_git.accept_hostkey = $accept_hostkey
$module.Result.win_git.update = $update
$module.Result.win_git.branch = $branch


$git_output = ""
$rc = 0

# main starts

try {

    FindGit

    if ($replace_dest) {
        PrepareDestination
    }
    if ([system.uri]::IsWellFormedUriString($repo, [System.UriKind]::Absolute)) {
        # http/https repositories doesn't need Ssh handle
        # fix to avoid wrong usage of CheckSshKnownHosts CheckSshIdentity for http/https
        $module.Result.win_git.valid_url = "$repo is valid url"
    }
    else {
        try {
            CheckSshKnownHosts
        }
        catch {
            AddToKnownHosts
        }
        try {
            CheckSshIdentity
        }
        catch {
            $module.FailJson("Error while CheckSshIdentity process on cloning $repo to $dest! Msg: $ErrorMessage - $git_output", $_)
        }
    }
    try {
        if ($clone) {
            clone
        }
    }
    catch {
        $module.FailJson("Error while clone process on cloning $repo to $dest! Msg: $ErrorMessage - $git_output", $_)
    }
    if ($update) {
        update
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    $module.FailJson("Error cloning $repo to $dest! Msg: $ErrorMessage - $git_output", $_)
}

$module.Result.win_git.msg = $cmd_msg
$module.Result.win_git.changed = $changed

$module.ExitJson()


