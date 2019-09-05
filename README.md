# Git old branches delete

The script deletes merged or non-merged branches older than a specified time from the target git repository,
excluding the master branch automatically.


## Usage info

The script runs as default in **_dry-run_** mode, so you can see what actions is going to take before performing
a real execution specifying `--execute`.

Command:

```
git-old-branches-delete.sh [options] <repo-dir>
```

All the valid options are:

```
-d, --days               days [defaults to 91]
-m, --merged             delete merged branches [default]
-n, --no-merged          delete non-merged branches
-e, --execute            run the script pushing changes to git
-h, --help               show usage help

--debug                  show debug messages
```

## Usage examples

Perform a **_dry-run_** deleting merged branches older than 91 days (three months):

```
git-old-branches-delete.sh /my/repository
```

<br>

Perform a **_dry-run_** deleting non-merged branches older than 91 days (three months):

```
git-old-branches-delete.sh --no-merged /my/repository
```

<br>

Perform a **_dry-run_** deleting merged branches older than 5 months:

```
git-old-branches-delete.sh --merged --days 152 /my/repository
```

(Note that `--merge` can be left out as it is the default value)
<br>
<br>

Perform a **_dry-run_** deleting merged branches older than 5 months and showing debug messages:

```
git-old-branches-delete.sh --debug --merged --days 152 /my/repository
```

(Note that `--merge` can be left out as it is the default value)
<br>
<br>

Perform a **_real_** execution deleting merged branches older than 5 months:

```
git-old-branches-delete.sh --days 152 /my/repository --execute
```
<br>

## Quick days amount reference

Delete branches older than:

- One year `-d 365`
- Eight months `-d 243`
- Five months `-d 152`
- Three months `-d 91`
- Two months `-d 60`
- One month `-d 30`

<br>
<br>


## Feedback

Suggestions and improvements
[welcome](https://github.com/salv0/git-old-branches-delete/issues)!
