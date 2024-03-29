#!/usr/bin/env bash
#
# MIT License
#
# Copyright (c) 2019 Salvatore Tipaldi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Abort on nonzero exitstatus
set -o errexit

#////////////////////////////////////////
# COLORS & PRINT FUNCTIONS
#////////////////////////////////////////
initialize_colors() {
  readonly red=$'\e[1;31m'
  readonly grn=$'\e[1;32m'
  readonly yel=$'\e[1;33m'
  readonly blu=$'\e[1;34m'
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

print_branch_stats() {
  local branch="$1"
  local branch_date="$2"
  local current_timestamp="$3"
  local branch_date_timestamp="$4"
  local days_diff="$5"

  print_green "Selected branch: ${branch}"
  if [[ "$debug" == true ]]; then
    echo "    --- Full branch date: ${branch_date}"
    echo "    --- Y-m-d date: ${branch_date}"
    echo "    --- Current timestamp: ${current_timestamp}"
    echo "    --- Branch date timestamp: ${branch_date_timestamp}"
  fi
  echo "    --- Last commit on branch was ${cyn}$days_diff${end} days ago"
}

print_debug_message() {
  if ! [[ "$debug" == true ]]; then
    return
  fi

  local message=$1
  print_yel "[DEBUG]  ${message}"
}

print_dry_run_header() {
  if [[ "$dry_run" == true ]]; then
    print_blue "================= DRY RUN STARTED ================="
  fi
}

print_dry_run_footer() {
  if [[ "$dry_run" == true ]]; then
    print_blue "================= DRY RUN FINISHED ================="
  fi
}

#////////////////////////////////////////
# SCRIPT FUNCTIONS
#////////////////////////////////////////

delete_branch() {
  local branch=$1

  if [[ "$dry_run" == true ]]; then
    print_red "    --- Will delete the branch\n\n"
  else
    print_red "    --- Deleting branch locally and on remote\n\n"

    print_debug_message "Command: git -C ${target_git_repo_dir} branch -D $branch"
    git -C ${target_git_repo_dir} branch -D $branch

    print_debug_message "Command: git -C ${target_git_repo_dir} push --delete origin $branch"
    git -C ${target_git_repo_dir} push --delete origin $branch
  fi
}

checkout_master_branch() {
  git -C ${target_git_repo_dir} checkout master
}

prune_local_git_cache() {
  print_action "Pruning local cache of remote branches..."
  git -C ${target_git_repo_dir} fetch --prune origin
}

old_git_branches_delete() {
  # Capture global variables
  local dry_run=$dry_run
  local target_git_repo_dir=$target_git_repo_dir
  local delete_merged_branches=$delete_merged_branches
  local execution_days=$execution_days

  print_dry_run_header
  prune_local_git_cache

  print_action "Retrieving the list of branches..."
  local branches=
  if [[ "$delete_merged_branches" == true ]]; then
    print_debug_message "Command: git -C ${target_git_repo_dir} branch -r --merged | grep -Ev 'master' | sed 's/origin\///'"
    branches=$(git -C ${target_git_repo_dir} branch -r --merged | grep -Ev 'master' | sed 's/origin\///')
    print_action "Deleting merged branches older than ${execution_days} days...\n"
  else
    print_debug_message "Command: git -C ${target_git_repo_dir} branch -r --no-merged | grep -Ev 'master' | sed 's/origin\///'"
    branches=$(git -C ${target_git_repo_dir} branch -r --no-merged | grep -Ev 'master' | sed 's/origin\///')
    print_action "Deleting non merged branches older than ${execution_days} days...\n"
  fi

  if [[ ! -z "$branches" ]]; then
    # Checkout master branch to avoid possible "Cannot delete branch 'xxx' checked out at yyyy"
    checkout_master_branch

    for branch in $branches; do
      # Get the date in format 2016-09-23 14:40:54 +0200
      local branch_date=$(git -C ${target_git_repo_dir} show -s --format=%ci origin/${branch})

      # Extract only the date part (remove time and timezone)
      branch_date=$(echo ${branch_date} | cut -d' ' -f 1)

      local current_timestamp=$(date +%s)

      local branch_date_timestamp=$(date -j -f "%Y-%m-%d" "${branch_date}" "+%s")

      local days_diff=$((($current_timestamp - $branch_date_timestamp) / 60 / 60 / 24))

      if [[ "$days_diff" -gt $execution_days ]]; then
        print_branch_stats "$branch" "$branch_date" "$current_timestamp" "$branch_date_timestamp" "$days_diff"
        delete_branch "$branch"
      fi
    done

    prune_local_git_cache
  else
    print_green "Found no branches to delete\n"
  fi

  print_action "Finished."
  print_dry_run_footer
}

initialize_settings_from_commandline() {
  while [ "$1" != "" ]; do
    case $1 in
    --debug)
      debug=true
      ;;
    -d | --days)
      shift
      execution_days="$1"
      check_valid_days $execution_days
      ;;
    -m | --merged)
      delete_merged_branches=true
      ;;
    -n | --no-merged)
      delete_merged_branches=false
      ;;
    -e | --execute)
      dry_run=false
      ;;
    -h | --help)
      usage
      exit
      ;;
    -* | --*)
      local invalid_option="$1"
      print_error_and_usage "Invalid option ${invalid_option}"
      ;;
    *)
      target_git_repo_dir="$1"
      check_valid_dir $target_git_repo_dir
      ;;
    esac
    shift
  done

  # Lock-in script's execution values captured from the command line
  readonly debug
  readonly dry_run
  readonly target_git_repo_dir
  readonly delete_merged_branches
  readonly execution_days

  print_debug_message "Setting up the script with dry_run=${dry_run} days=${execution_days} delete_merged_branches=${delete_merged_branches} target_repo_dir=${target_git_repo_dir}"
}

check_git_installed() {
  print_debug_message "Checking if git is installed correctly"

  if ! [[ -x "$(command -v git)" ]]; then
    print_error_and_usage 'git is not installed.'
  fi
}

check_valid_git_repo() {
  local repo_dir=$1

  print_debug_message "Checking if ${repo_dir} is a valid git repo"
  print_debug_message "Command: git -C ${repo_dir} rev-parse --is-inside-work-tree"

  if ! [[ "$(git -C ${repo_dir} rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]; then
    print_error_and_usage 'The specified path is not a valid git repository.'
  fi
}

check_valid_dir() {
  local repo_dir=$1

  if [[ ! -d "${repo_dir}" ]]; then
    print_error_and_usage "Parameter <repo-dir> invalid or not specified."
  fi
}

check_valid_days() {
  local days=$1

  if ! [[ "${days}" -gt "0" ]] 2>/dev/null; then
    print_error_and_usage "The number of days is invalid."
  fi
}

usage() {
  cat <<-EOF
    usage: ${PROGNAME} [options] <repo-dir>

    The script deletes merged or non-merged branches older than
    a specified time (in days) from the target git repository.

    - The master branch is always excluded automatically.
    - The script will run as default in dry-run mode.
    - To perform a real execution specify --execute

    OPTIONS:
       -d, --days               days [defaults to 91]
       -m, --merged             delete merged branches [default]
       -n, --no-merged          delete non-merged branches
       -e, --execute            run the script pushing changes to git
       -h, --help               show this help
       --debug                  show debug messages


    Examples:
       [Dry run] Deletes merged branches older than 3 months
       ${PROGNAME} <repo-dir>

       [Dry run] Deletes non-merged branches older than 3 months
       ${PROGNAME} --no-merged <repo-dir>

       [Dry run] Deletes merged branches older than 5 months
       ${PROGNAME} -d 152 <repo-dir>

       Deletes merged branches older than 3 months
       ${PROGNAME} <repo-dir> --execute

    Quick time values references:
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
  local debug=false
  local dry_run=true
  local target_git_repo_dir=''
  local delete_merged_branches=true
  local execution_days=$THREE_MONTHS

  initialize_colors
  initialize_settings_from_commandline $ARGS

  check_git_installed
  check_valid_git_repo $target_git_repo_dir

  old_git_branches_delete
}

main "$@"
