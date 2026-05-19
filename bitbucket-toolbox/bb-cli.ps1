#Requires -Version 7.0
<#
.SYNOPSIS
    Bitbucket Cloud REST API wrapper (read-only) — Windows PowerShell port of bb-cli.sh.

.DESCRIPTION
    Mirrors bb-cli.sh exactly: same commands, same arguments, same JSON shape.

    SECURITY MANIFEST
    -----------------
    Environment variables read:
      - BITBUCKET_API_TOKEN  (used for Bearer auth, never logged)
      - BITBUCKET_WORKSPACE  (workspace slug for API URL construction)

    External endpoints called:
      - https://api.bitbucket.org/2.0/*  (Bitbucket Cloud REST API, read-only)

    Local files read/written:
      - None. All output goes to stdout/stderr.

    Network access:
      - HTTPS GET requests only. No data is sent beyond the Authorization header.

    Dependencies: PowerShell 7+ (pwsh). No external binaries required.
    Auth: Authorization: Bearer <BITBUCKET_API_TOKEN>
    Outputs: JSON to stdout, errors to stderr.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = 'help',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

# --- Environment validation ---
foreach ($v in 'BITBUCKET_API_TOKEN', 'BITBUCKET_WORKSPACE') {
    $val = [Environment]::GetEnvironmentVariable($v)
    if ([string]::IsNullOrEmpty($val)) {
        [Console]::Error.WriteLine('{"error": "Missing env var: ' + $v + '"}')
        exit 1
    }
}

$script:Base = 'https://api.bitbucket.org/2.0'
$script:Workspace = $env:BITBUCKET_WORKSPACE
$script:Headers = @{
    'Authorization' = "Bearer $env:BITBUCKET_API_TOKEN"
    'Accept'        = 'application/json'
}

# --- Helpers ---
function Write-ErrorJson {
    param([hashtable]$Obj)
    [Console]::Error.WriteLine(($Obj | ConvertTo-Json -Compress))
    exit 1
}

function Test-RepoSlug([string]$s) {
    if ($s -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
        Write-ErrorJson @{ error = "Invalid repository slug: '$s'. Must be alphanumeric with dashes, underscores, or dots." }
    }
}

function Test-PrId([string]$id) {
    if ($id -notmatch '^[1-9][0-9]*$') {
        Write-ErrorJson @{ error = "Invalid PR ID: '$id'. Must be a positive integer." }
    }
}

function Test-Ref([string]$ref) {
    if ($ref -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._/-]*$') {
        Write-ErrorJson @{ error = "Invalid branch/revision: '$ref'. Contains disallowed characters." }
    }
}

function Test-State([string]$state) {
    if ($state -notin 'OPEN', 'MERGED', 'DECLINED', 'SUPERSEDED') {
        Write-ErrorJson @{ error = "Invalid state: '$state'. Must be OPEN, MERGED, DECLINED, or SUPERSEDED." }
    }
}

function ConvertTo-UrlEncoded([string]$s) { [uri]::EscapeDataString($s) }

function Invoke-BbGet([string]$Url) {
    try {
        # -PreserveAuthorizationOnRedirect is required: Bitbucket's PR diff/diffstat
        # endpoints 302-redirect to a commit-range URL, and the default behavior of
        # Invoke-WebRequest is to drop the Authorization header on redirect.
        $resp = Invoke-WebRequest -Uri $Url -Headers $script:Headers -Method Get `
            -UseBasicParsing -PreserveAuthorizationOnRedirect
        return $resp.Content
    } catch {
        $code = 0
        if ($_.Exception -and $_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        }
        Write-ErrorJson @{ error = "HTTP $code"; url = $Url }
    }
}

function Invoke-BbGetJson([string]$Url) {
    Invoke-BbGet $Url | ConvertFrom-Json
}

function Invoke-BbGetPaginated([string]$Url) {
    $all = [System.Collections.Generic.List[object]]::new()
    $next = $Url
    while ($next) {
        $page = Invoke-BbGetJson $next
        if ($null -ne $page.values) {
            foreach ($v in $page.values) { [void]$all.Add($v) }
        }
        $next = if ($page.PSObject.Properties.Name -contains 'next') { $page.next } else { $null }
    }
    [pscustomobject]@{ size = $all.Count; values = $all }
}

function Out-Json($Obj) { $Obj | ConvertTo-Json -Depth 20 }

function Out-JsonArray($Items) {
    $arr = @($Items)
    if ($arr.Count -eq 0) { return '[]' }
    $arr | ConvertTo-Json -Depth 20 -AsArray
}

# --- Argument helpers (operate on $script:Rest) ---
function Get-OptArg([int]$i, [string]$default = '') {
    if ($script:Rest -and $i -lt $script:Rest.Count) { return $script:Rest[$i] }
    return $default
}

function Get-ReqArg([int]$i, [string]$usage) {
    if ($script:Rest -and $i -lt $script:Rest.Count -and -not [string]::IsNullOrEmpty($script:Rest[$i])) {
        return $script:Rest[$i]
    }
    Write-ErrorJson @{ error = $usage }
}

# --- Commands ---

function Invoke-CmdRepos {
    $data = Invoke-BbGetPaginated "$script:Base/repositories/$script:Workspace`?pagelen=100"
    $list = foreach ($r in $data.values) {
        [pscustomobject]@{
            slug       = $r.slug
            name       = $r.name
            full_name  = $r.full_name
            language   = $r.language
            updated    = $r.updated_on
            is_private = $r.is_private
            url        = $r.links.html.href
        }
    }
    Out-JsonArray $list
}

function Invoke-CmdPrs {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 prs REPO [STATE]"
    $state = Get-OptArg 1 'OPEN'
    Test-RepoSlug $repo
    Test-State $state
    $data = Invoke-BbGetPaginated "$script:Base/repositories/$script:Workspace/$repo/pullrequests?state=$state&pagelen=100"
    $prs = foreach ($pr in $data.values) {
        [pscustomobject]@{
            id          = $pr.id
            title       = $pr.title
            author      = $pr.author.display_name
            source      = $pr.source.branch.name
            destination = $pr.destination.branch.name
            state       = $pr.state
            created     = $pr.created_on
            updated     = $pr.updated_on
            url         = $pr.links.html.href
        }
    }
    Out-Json ([pscustomobject]@{
        total        = $data.size
        pullrequests = @($prs)
    })
}

function Invoke-CmdPr {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 pr REPO PR_ID"
    $prId = Get-ReqArg 1 "Usage: bb-cli.ps1 pr REPO PR_ID"
    Test-RepoSlug $repo
    Test-PrId $prId
    $pr = Invoke-BbGetJson "$script:Base/repositories/$script:Workspace/$repo/pullrequests/$prId"
    $reviewers = foreach ($r in $pr.reviewers) { $r.display_name }
    Out-Json ([pscustomobject]@{
        id            = $pr.id
        title         = $pr.title
        description   = $pr.description
        author        = $pr.author.display_name
        source        = $pr.source.branch.name
        destination   = $pr.destination.branch.name
        state         = $pr.state
        reviewers     = @($reviewers)
        created       = $pr.created_on
        updated       = $pr.updated_on
        comment_count = $pr.comment_count
        url           = $pr.links.html.href
    })
}

function Invoke-CmdDiffstat {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 diffstat REPO PR_ID"
    $prId = Get-ReqArg 1 "Usage: bb-cli.ps1 diffstat REPO PR_ID"
    Test-RepoSlug $repo
    Test-PrId $prId
    $data = Invoke-BbGetPaginated "$script:Base/repositories/$script:Workspace/$repo/pullrequests/$prId/diffstat?pagelen=100"
    $totalAdded = 0
    $totalRemoved = 0
    $files = foreach ($f in $data.values) {
        $newPath = if ($f.new) { $f.new.path } else { $null }
        $oldPath = if ($f.old) { $f.old.path } else { $null }
        $added = if ($null -ne $f.lines_added) { [int]$f.lines_added } else { 0 }
        $removed = if ($null -ne $f.lines_removed) { [int]$f.lines_removed } else { 0 }
        $totalAdded += $added
        $totalRemoved += $removed
        [pscustomobject]@{
            path          = if ($newPath) { $newPath } else { $oldPath }
            status        = $f.status
            lines_added   = $added
            lines_removed = $removed
        }
    }
    Out-Json ([pscustomobject]@{
        files_changed = @($files).Count
        total_added   = $totalAdded
        total_removed = $totalRemoved
        files         = @($files)
    })
}

function Invoke-CmdDiff {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 diff REPO PR_ID [FILEPATH]"
    $prId = Get-ReqArg 1 "Usage: bb-cli.ps1 diff REPO PR_ID [FILEPATH]"
    $filePath = Get-OptArg 2 ''
    Test-RepoSlug $repo
    Test-PrId $prId
    $url = "$script:Base/repositories/$script:Workspace/$repo/pullrequests/$prId/diff"
    if ($filePath) { $url = "$url`?path=$(ConvertTo-UrlEncoded $filePath)" }
    Invoke-BbGet $url
}

function Invoke-CmdComments {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 comments REPO PR_ID"
    $prId = Get-ReqArg 1 "Usage: bb-cli.ps1 comments REPO PR_ID"
    Test-RepoSlug $repo
    Test-PrId $prId
    $data = Invoke-BbGetPaginated "$script:Base/repositories/$script:Workspace/$repo/pullrequests/$prId/comments?pagelen=100"
    $comments = foreach ($c in $data.values) {
        $inline = $null
        if ($c.inline) {
            $inline = [pscustomobject]@{
                path = $c.inline.path
                from = $c.inline.from
                to   = $c.inline.to
            }
        }
        $raw = if ($c.content -and $c.content.raw) { $c.content.raw } else { $null }
        $truncated = if ($raw) {
            if ($raw.Length -gt 500) { $raw.Substring(0, 500) } else { $raw }
        } else { $null }
        [pscustomobject]@{
            id      = $c.id
            author  = $c.user.display_name
            content = $truncated
            inline  = $inline
            created = $c.created_on
        }
    }
    Out-Json ([pscustomobject]@{
        count    = @($comments).Count
        comments = @($comments)
    })
}

function Invoke-CmdPrCommits {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 pr-commits REPO PR_ID"
    $prId = Get-ReqArg 1 "Usage: bb-cli.ps1 pr-commits REPO PR_ID"
    Test-RepoSlug $repo
    Test-PrId $prId
    $data = Invoke-BbGetPaginated "$script:Base/repositories/$script:Workspace/$repo/pullrequests/$prId/commits?pagelen=100"
    $list = foreach ($c in $data.values) {
        $hash = $c.hash
        if ($hash -and $hash.Length -gt 12) { $hash = $hash.Substring(0, 12) }
        $msg = if ($c.message) { ($c.message -split "`n", 2)[0] } else { '' }
        [pscustomobject]@{
            hash    = $hash
            message = $msg
            author  = $c.author.raw
            date    = $c.date
        }
    }
    Out-JsonArray $list
}

function Invoke-CmdBranches {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 branches REPO [filter]"
    $filter = Get-OptArg 1 ''
    Test-RepoSlug $repo
    $url = "$script:Base/repositories/$script:Workspace/$repo/refs/branches?pagelen=100"
    if ($filter) { $url = "$url&q=name~`"$filter`"" }
    $data = Invoke-BbGetPaginated $url
    $list = foreach ($b in $data.values) {
        $hash = if ($b.target) { $b.target.hash } else { $null }
        if ($hash -and $hash.Length -gt 12) { $hash = $hash.Substring(0, 12) }
        [pscustomobject]@{
            name   = $b.name
            hash   = $hash
            date   = $b.target.date
            author = $b.target.author.raw
        }
    }
    Out-JsonArray $list
}

function Invoke-CmdCommits {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 commits REPO [BRANCH]"
    $branch = Get-OptArg 1 'master'
    Test-RepoSlug $repo
    Test-Ref $branch
    $data = Invoke-BbGetPaginated "$script:Base/repositories/$script:Workspace/$repo/commits/$branch`?pagelen=100"
    $list = foreach ($c in $data.values) {
        $hash = $c.hash
        if ($hash -and $hash.Length -gt 12) { $hash = $hash.Substring(0, 12) }
        $msg = if ($c.message) { ($c.message -split "`n", 2)[0] } else { '' }
        [pscustomobject]@{
            hash    = $hash
            message = $msg
            author  = $c.author.raw
            date    = $c.date
        }
    }
    Out-JsonArray $list
}

function Invoke-CmdFile {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 file REPO FILEPATH [REV]"
    $filePath = Get-ReqArg 1 "Usage: bb-cli.ps1 file REPO FILEPATH [REV]"
    $rev = Get-OptArg 2 'master'
    Test-RepoSlug $repo
    Test-Ref $rev
    Invoke-BbGet "$script:Base/repositories/$script:Workspace/$repo/src/$rev/$filePath"
}

function Invoke-CmdLs {
    $repo = Get-ReqArg 0 "Usage: bb-cli.ps1 ls REPO [PATH] [REV]"
    $path = Get-OptArg 1 ''
    $rev = Get-OptArg 2 'master'
    Test-RepoSlug $repo
    Test-Ref $rev
    $data = Invoke-BbGetPaginated "$script:Base/repositories/$script:Workspace/$repo/src/$rev/$path`?pagelen=100"
    $list = foreach ($v in $data.values) {
        [pscustomobject]@{
            path = $v.path
            type = $v.type
            size = $v.size
        }
    }
    Out-JsonArray $list
}

function Invoke-CmdHelp {
    @"
Usage: bb-cli.ps1 <command> [args]

Commands:
  repos                          List all repos in workspace
  prs REPO [STATE]               List pull requests (OPEN/MERGED/DECLINED)
  pr REPO PR_ID                  Get PR details
  diffstat REPO PR_ID            Per-file change summary
  diff REPO PR_ID [FILEPATH]     Full diff, or diff for a single file
  comments REPO PR_ID            PR comments (inline + general)
  pr-commits REPO PR_ID          Commits in a PR
  branches REPO [filter]         List branches
  commits REPO [BRANCH]          Recent commits on a branch
  file REPO FILEPATH [REV]       Read file contents
  ls REPO [PATH] [REV]           List directory contents

Env: BITBUCKET_API_TOKEN, BITBUCKET_WORKSPACE
"@
}

# --- Dispatch ---
switch ($Command) {
    'repos'      { Invoke-CmdRepos }
    'prs'        { Invoke-CmdPrs }
    'pr'         { Invoke-CmdPr }
    'diffstat'   { Invoke-CmdDiffstat }
    'diff'       { Invoke-CmdDiff }
    'comments'   { Invoke-CmdComments }
    'pr-commits' { Invoke-CmdPrCommits }
    'branches'   { Invoke-CmdBranches }
    'commits'    { Invoke-CmdCommits }
    'file'       { Invoke-CmdFile }
    'ls'         { Invoke-CmdLs }
    'help'       { Invoke-CmdHelp }
    '--help'     { Invoke-CmdHelp }
    '-h'         { Invoke-CmdHelp }
    default {
        [Console]::Error.WriteLine('{"error":"Unknown command: ' + $Command + '"}')
        exit 1
    }
}
