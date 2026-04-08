$(require.d source); require logging
# Discover subcommand names from a search directory.
# Finds <dir>/<name>.sh and <dir>/<name>/<name>.sh
# If dir is empty, does nothing (no search-based discovery).
_sc_list() {
	local dir="$1"
	[[ -d "$dir" ]] || return 0

	local f name

	for f in "$dir"/*.sh; do
		[[ -f "$f" ]] || continue
		name="${f##*/}"
		printf '%s\n' "${name%.sh}"
	done

	for f in "$dir"/*/; do
		[[ -d "$f" ]] || continue
		name="${f%/}"
		name="${name##*/}"
		[[ -f "$dir/$name/$name.sh" ]] || continue
		printf '%s\n' "$name"
	done
}

# Discover predefined help functions matching <prefix>_help_*.
# Extracts subcommand names from function names.
_sc_list_predefined() {
	local prefix="$1"
	local pattern="${prefix}_help_"
	local fn subcmd

	while IFS= read -r fn; do
		# Extract subcommand name from function name: remove prefix and help_
		subcmd="${fn#${pattern}}"
		[[ -n "$subcmd" ]] && printf '%s\n' "$subcmd"
	done < <(declare -F | awk -v p="$pattern" '$3 ~ "^" p {print $3}')
}

# Source the file for a subcommand.
# Tries <dir>/<subcmd>.sh, then <dir>/<subcmd>/<subcmd>.sh
_sc_load() {
	local subcmd="$1" dir="$2"

	local f1="$dir/$subcmd.sh"
	local f2="$dir/$subcmd/$subcmd.sh"

	if [[ -f "$f1" ]]; then
		# shellcheck source=/dev/null
		source "$f1"
	elif [[ -f "$f2" ]]; then
		# shellcheck source=/dev/null
		source "$f2"
	fi
}

# Print help for a prefix/search_dir combination.
#
# 1. Calls <prefix>_help if defined.
# 2. Otherwise prints default usage + lists subcommands from both:
#    - Search directory (if provided)
#    - Predefined help functions (<prefix>_help_<subcmd>)
#    Calls <prefix>_help_<subcmd> for each that has such a function.
_sc_help() {
	local prefix="$1" dir="$2"
	local display="${prefix//_/-}"
	local help_fn="${prefix}_help"

	if declare -f "$help_fn" >/dev/null 2>&1; then
		"$help_fn"
	else
		printf 'Usage: %s <subcommand> [args...]\n' "$display"
		printf '       %s -h\n' "$display"
	fi

	local subcmds
	# Combine subcommands from search directory and predefined help functions
	mapfile -t subcmds < <(
		{
			_sc_list "$dir"
			_sc_list_predefined "$prefix"
		} | sort -u
	)
	[[ ${#subcmds[@]} -eq 0 ]] && return

	printf '\nSubcommands:\n'

	local subcmd sub_help_fn
	for subcmd in "${subcmds[@]}"; do
		_sc_load "$subcmd" "$dir"
		sub_help_fn="${prefix}_help_${subcmd//-/_}"
		if declare -f "$sub_help_fn" >/dev/null 2>&1; then
			printf '\n'
			"$sub_help_fn"
		else
			printf '  %s\n' "$subcmd"
		fi
	done
}

# subcommand_run [-p prefix] [-d search_dir] [subcommand] [args...]
#
# Dispatches to <prefix>_cmd_<subcommand>, with lazy loading from
# <search_dir>/<subcommand>.sh or <search_dir>/<subcommand>/<subcommand>.sh
# (if -d is provided).
#
# Options:
#   -p prefix      Function-name prefix. Hyphens are converted to underscores.
#                  Default: basename of $0, with hyphens converted to underscores.
#   -d search_dir  Directory to lazy-load subcommand files from.
#                  Optional; if not provided, only predefined functions and
#                  <prefix>_cmd_<subcommand> are available.
#
# Behaviour with no subcommand:
#   - Calls <prefix>_cmd if defined, otherwise prints help and returns 0.
#
# Behaviour with -h / --help as the subcommand:
#   - Prints help and returns 0.
#
# Behaviour with an unrecognised subcommand after lazy loading:
#   - Calls log_error and returns 1.
subcommand_run() {
	local prefix="" dir=""
	local _prefix_set=0 _dir_set=0

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-p)
				if [[ $# -lt 2 ]]; then
					log_error "Invalid Syntax"
					_sc_help "${prefix:-${0##*/}}" "${dir:-}"
					return 1
				fi
				prefix="${2//-/_}"
				_prefix_set=1
				shift 2
				;;
			-d)
				if [[ $# -lt 2 ]]; then
					log_error "Invalid Syntax"
					_sc_help "${prefix:-${0##*/}}" "${dir:-}"
					return 1
				fi
				dir="$2"
				_dir_set=1
				shift 2
				;;
			--)
				shift
				break
				;;
			-*)
				log_error "Invalid Syntax"
				_sc_help "${prefix:-${0##*/}}" "${dir:-}"
				return 1
				;;
			*)
				break
				;;
		esac
	done

	if [[ $_prefix_set -eq 0 ]]; then
		local _bn="${0##*/}"
		prefix="${_bn//-/_}"
	fi

	# No subcommand given
	if [[ $# -eq 0 ]]; then
		local no_cmd_fn="${prefix}_cmd"
		if declare -f "$no_cmd_fn" >/dev/null 2>&1; then
			"$no_cmd_fn"
		else
			_sc_help "$prefix" "$dir"
		fi
		return
	fi

	local subcmd="$1"
	shift

	# Help flag passed as subcommand
	if [[ "$subcmd" == "-h" || "$subcmd" == "--help" ]]; then
		_sc_help "$prefix" "$dir"
		return
	fi

	local fn="${prefix}_cmd_${subcmd//-/_}"

	# Try direct call (function already in scope)
	if declare -f "$fn" >/dev/null 2>&1; then
		"$fn" "$@"
		return
	fi

	# Lazy load, then retry
	_sc_load "$subcmd" "$dir"
	if declare -f "$fn" >/dev/null 2>&1; then
		"$fn" "$@"
		return
	fi

	log_error "Unknown subcommand: $subcmd"
	return 1
}
