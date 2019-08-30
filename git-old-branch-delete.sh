#!/usr/bin/env bash
#
# Copyright 2019 Salvatore Tipaldi
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# Abort on nonzero exitstatus
set -o errexit
# Don't hide errors within pipes
set -o pipefail

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

print_error_and_usage() {
  print_red "Error: $1\n" >&2
  print_cyn "Please specify -h for usage manual"
  exit 1
}

print_action() {
  local message=$1
  print_blue "[ACTION] ${message}"
}

debug_message() {
  local message=$1
  print_yel "[DEBUG] ${message}"
}

#////////////////////////////////////////
# SCRIPT FUNCTIONS
#////////////////////////////////////////

old_git_branches_delete() {
  # Capture global variables
  local dry_run=$dry_run
  local target_git_repo_dir=$target_git_repo_dir
  local delete_merged_branches=$delete_merged_branches
  local execution_days=$execution_days

  print_action "Pruning local cache of remote branches first..."
  git -C ${target_git_repo_dir} fetch --prune origin

  print_action "Retrieving list of branches for deletion..."
  local branches=
  if [[ delete_merged_branches ]]; then
    debug_message "Command: git -C ${target_git_repo_dir} branch -r --merged | grep -v master | grep -v developer | sed 's/origin\///'"
    branches=$(git -C ${target_git_repo_dir} branch -r --merged | grep -v master | grep -v developer | sed 's/origin\///')
  else
    debug_message "Command: git -C ${target_git_repo_dir} branch -r --no-merged | grep -v master | grep -v developer | sed 's/origin\///'"
    branches=$(git -C ${target_git_repo_dir} branch -r --no-merged | grep -v master | grep -v developer | sed 's/origin\///')
  fi

  print_action "Starting branches deletion.."
  for branch in $branches; do
    # Get the date in format 2016-09-23 14:40:54 +0200
    local branch_date=$(git -C ${target_git_repo_dir} show -s --format=%ci origin/${branch})

    # Extract only the date part (remove time and timezone)
    branch_date=$(echo ${branch_date} | cut -d' ' -f 1)

    local current_timestamp=$(date +%s)

    local branch_date_timestamp=$(date -j -f "%Y-%m-%d" "${branch_date}" "+%s")

    local days_diff=$((($current_timestamp - $branch_date_timestamp) / 60 / 60 / 24))

    if [[ "$days_diff" -gt $THREE_MONTHS ]]; then
      print_green "Selected branch: $branch"
      echo "    --- Full branch date: $branch_date"
      echo "    --- Y-m-d date: $branch_date"
      echo "    --- Current timestamp: $current_timestamp"
      echo "    --- Branch date timestamp: $branch_date_timestamp"
      echo "    --- Last commit on $branch branch was ${cyn}$days_diff${end} days ago"

      print_red "    --- Deleting the old branch $branch"

      # Comment the following line if you wanna do a dry run :)
      # git push origin --delete $branch
      echo ""
      echo ""
    fi
  done
  print_action "Deleting old branches finished."
}

initialize_settings_from_commandline() {
  while [ "$1" != "" ]; do
    case $1 in
    -d | --days)
      shift
      execution_days=$1
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
      print_error_and_usage "invalid option ${invalid_option}"
      ;;
    *)
      target_git_repo_dir=$1
      ;;
    esac
    shift
  done

  check_valid_dir $target_git_repo_dir
  check_valid_days $execution_days

  # Lock-in script's execution values captured from the command line
  readonly dry_run
  readonly target_git_repo_dir
  readonly delete_merged_branches
  readonly execution_days

  debug_message "Setting up the script with dry_run=${dry_run} days=${execution_days} delete_merged_branches=${delete_merged_branches} target_repo_dir=${target_git_repo_dir}"
}

check_git_installed() {
  if ! [[ -x "$(command -v git)" ]]; then
    print_error_and_usage 'git is not installed.'
  fi
}

check_valid_git_repo() {
  local repo_dir=$1

  debug_message "Command: git -C ${repo_dir} rev-parse --is-inside-work-tree"

  if ! [[ "$(git -C ${repo_dir} rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]; then
    print_error_and_usage 'The specified path is not a valid git repository.'
  fi
}

check_valid_dir() {
  local repo_dir=$1

  if [[ ! -d "${repo_dir}" ]]; then
    print_error_and_usage "parameter <repo-dir> invalid or not specified."
  fi
}

check_valid_days() {
  local days=$1

  if ! [[ "${days}" -gt "0" ]] 2>/dev/null; then
    print_error_and_usage "number of days is invalid."
  fi
}

usage() {
  cat <<-EOF
    usage: ${PROGNAME} [options] <repo-dir>

    The script deletes merged (default) or non-merged branches older than
    a specified time (in days) from the target git repository.

    The script will run automatically in dry-run mode.
    For a real execution specify --execute.

    OPTIONS:
       -d --days                days [default 91]
       -m --merged              deletes merged branches [default]
       -n --no-merged           deletes non-merged branches
       -e --execute             run the script pushing changes to git
       -h --help                show this help


    Examples:
       [Dry run] Deletes merged branches older than 3 months
       ${PROGNAME} <repo-dir>

       [Dry run] Deletes non-merged branches older than 3 months
       ${PROGNAME} --no-merged <repo-dir>

       [Dry run] Deletes merged branches older than 5 months
       ${PROGNAME} -t 152 <repo-dir>

       Deletes merged branches older than 3 months
       ${PROGNAME} <repo-dir> --execute

    Quick time values reference:
      One year = 365
      Eight months = 243
      Five months = 152
      Three months = 91
      Two months = 60
      One month = 30
EOF
}

main() {
  # Globals
  readonly PROGNAME=$(basename $0)
  readonly ARGS="$@"
  readonly THREE_MONTHS=91

  # Default values
  local dry_run=1
  local target_git_repo_dir=''
  local delete_merged_branches=1
  local execution_days=$THREE_MONTHS

  initialize_colors
  initialize_settings_from_commandline $ARGS

  check_git_installed
  check_valid_git_repo $target_git_repo_dir

  old_git_branches_delete
}

main "$@"
