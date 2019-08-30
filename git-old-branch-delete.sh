#!/usr/bin/env bash

#////////////////////////////////////////
# COLORS & PRINT FUNCTIONS
#////////////////////////////////////////
initialize_colors() {
  readonly red=$'\e[1;31m'
  readonly grn=$'\e[1;32m'
  readonly yel=$'\e[1;33m'
  readonly blu=$'\e[1;34m'
  readonly mag=$'\e[1;35m'
  readonly cyn=$'\e[1;36m'
  readonly end=$'\e[0m'
}

print_green() {
  echo -e "${grn}$1${end}"
}

print_red() {
  echo -e "${red}$1${end}"
}

print_yel() {
  echo -e "${yel}$1${end}"
}

print_blue() {
  echo -e "${blu}$1${end}"
}

print_mag() {
  echo -e "${mag}$1${end}"
}

print_cyn() {
  echo -e "${cyn}$1${end}"
}

#////////////////////////////////////////
# SCRIPT FUNCTIONS
#////////////////////////////////////////

git_branches_delete() {
  # Prune local "cache" of remote branches first.
  git fetch --prune origin

  # Uncomment the following line (and comment the other) if you want to delete only merged branches
  # branches=$(git branch -r --merged | grep -v master | grep -v developer | sed 's/origin\///')
  branches=$(git branch -r --no-merged | grep -v master | grep -v developer | sed 's/origin\///')

  for branch in $branches; do
    # Get the date in format 2016-09-23 14:40:54 +0200
    branchDate=$(git show -s --format=%ci origin/$branch)

    # Extract only the date part (remove time and timezone)
    branchDate=$(echo $branchDate | cut -d' ' -f 1)

    currentTimestamp=$(date +%s)

    branchDateTimestamp=$(date -j -f "%Y-%m-%d" "$branchDate" "+%s")

    days=$((($currentTimestamp - $branchDateTimestamp) / 60 / 60 / 24))

    if [ "$days" -gt $THREE_MONTHS ]; then
      print_green "Selected branch: $branch"
      echo "    --- Full branch date: $branchDate"
      echo "    --- Y-m-d date: $branchDate"
      echo "    --- Current timestamp: $currentTimestamp"
      echo "    --- Branch date timestamp: $branchDateTimestamp"
      echo "    --- Last commit on $branch branch was ${cyn}$days${end} days ago"

      print_red "    --- Deleting the old branch $branch"

      # Comment the following line if you wanna do a dry run :)
      # git push origin --delete $branch
      echo ""
      echo ""
    fi
  done
  print_blue "Deleting old branches finished."
}

initialize() {
  initialize_colors
  initialize_settings $ARGS
}

print_error_and_usage() {
  print_red "$1\n" >&2
  print_cyn "Please specify -h for usage manual"
  exit 1
}

check_git_installed() {
  if ! [ -x "$(command -v git)" ]; then
    print_error_and_usage 'Error: git is not installed.'
  fi
}

check_valid_git_repo() {
  local repo_dir=$1

  debug_message "Command: git -C $repo_dir rev-parse --is-inside-work-tree"

  if ! [ "$(git -C $repo_dir rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]; then
    print_error_and_usage 'Error: The specified path is not a valid git repository.'
  fi
}

usage() {
  cat <<-EOF
    usage: $PROGNAME [options] <repo-dir>

    The script deletes merged (default) or non-merged branches older than
    a specified time from the target git repository.

    The script will run automatically in dry-run mode.
    For a real execution specify --execute.

    OPTIONS:
       -t --time                time in days [default 91]
       -m --merged              deletes merged branches [default]
       -n --no-merged           deletes non-merged branches
       -e --execute             run the script pushing changes to git
       -h --help                show this help


    Examples:
       [Dry run] Deletes merged branches older than 3 months
       $PROGNAME <repo-dir>

       [Dry run] Deletes non-merged branches older than 3 months
       $PROGNAME --no-merged <repo-dir>

       [Dry run] Deletes merged branches older than 5 months
       $PROGNAME -t 152 <repo-dir>

       Deletes merged branches older than 3 months
       $PROGNAME <repo-dir> --execute

    Quick time values reference:
      One year = 365
      Eight months = 243
      Five months = 152
      Three months = 91
      Two months = 60
      One month = 30
EOF
}

initialize_settings() {
  # Default settings
  local days=91 # 3 Months
  local delete_merged_branches=1
  local dry_run=1
  target_repo_dir=

  while [ "$1" != "" ]; do
    case $1 in
    -t | --time)
      shift
      days=$1
      ;;
    -m | --merged)
      delete_merged_branches=1
      ;;
    -n | --no-merged)
      delete_merged_branches=0
      ;;
    -e | --execute)
      dry_run=0
      ;;
    -h | --help)
      usage
      exit
      ;;
    -* | --*)
      local invalid_option=$1
      print_error_and_usage "Error: invalid option $invalid_option"
      ;;
    *)
      target_repo_dir=$1
      ;;
    esac
    shift
  done

  check_valid_dir $target_repo_dir
  # check_valid_days $check_valid_days
  debug_message "Setting up the script with dry_run=$dry_run days=$days delete_merged_branches=$delete_merged_branches target_repo_dir=$target_repo_dir"
}

check_valid_dir() {
  if [ ! -d "$1" ]; then
    print_error_and_usage "Error: repo-dir invalid or not specified."
  fi
}

debug_message() {
  local message=$1
  print_yel "[DEBUG] $1"
}

# Establish run order
main() {
  readonly PROGNAME=$(basename $0)
  readonly ARGS="$@"

  initialize

  check_git_installed
  check_valid_git_repo $target_repo_dir
  git_branches_delete
}

main "$@"