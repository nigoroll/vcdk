#!/bin/sh
#
# Copyright (C) 2017  Dridi Boukelmoune
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e
set -u

VCDK_PLUGIN_DIR=$(cd "$(dirname "$0")"; pwd)
VCDK_NAME_REGEX='^[[:alnum:]][[:alnum:]_-]*$'

options_iter() {
	func=$1
	shift

	status=0

	"$func" "--help" "display this message and exit" "$@" ||
	return 1

	OLD_IFS=$IFS
	IFS='|'
	spec=$(printf '%s' "$OPTIONS_SPEC" | tr '\n' '|')

	for line in $spec
	do
		opt=${line%%	*}
		dsc=${line##*	}
		"$func" "$opt" "$dsc" "$@" || status=$?
		test "$status" -eq 0 || break
	done
	IFS=$OLD_IFS

	return $status
}

options_parse() {
	opt_name=
	opt_arg=
	opt_shift=
	test $# -ge 1 || return 1

	opt_name=$1
	opt_shift=1

	opt_parse() {
		test "${1%=*}" = "${3%%=*}" || return 0

		if [ "${1%=*}" = "$1" ]
		then
			test "$1" = "$3" || usage_error "unknown option: $3"
			return 1
		fi

		if [ "$3" = "${3%%=*}" ]
		then
			opt_shift=2
		else
			opt_arg=${3#*=}
			test -n "$opt_arg" || usage_error "empty argument: $3"
		fi

		return 1
	}

	if options_iter opt_parse "$opt_name"
	then
		# didn't break out of the loop, no match
		test "${opt_name#-}" = "$opt_name" ||
		usage_error "unknown option: $opt_name"

		# not an option, end of parsing
		return 1
	fi

	if [ $opt_shift -eq 2 ]
	then
		test $# -ge 2 || usage_error "missing argument: $opt_name"
		opt_arg=$2
		test -n "$opt_arg" || usage_error "empty argument: $opt_name"
	fi

	opt_name=${opt_name#--}
	opt_name=${opt_name%%=*}
}

options_init() {
	help=false
	opt_ind=0
	while options_parse "$@"
	do
		opt_value=$(eval echo "\$$opt_name")
		test -n "$opt_value" && (
			test -n "$opt_arg" ||
			test "$opt_value" != false
		) && usage_error "option already set: --$opt_name"

		eval "$opt_name='${opt_arg:-true}'"
		shift $opt_shift
		opt_ind=$((opt_ind + opt_shift))
	done

	if $help
	then
		usage
		exit
	fi
}

usage() {
	print_option_usage() {
		printf '    %-20s %s\n' "$1" "$2"
	}

	printf '%s' "$OPTIONS_USAGE"
	options_iter print_option_usage
}

usage_error() {
	printf 'vcdk: %s\n\n' "$*" >&2
	usage >&2
	exit 1
}

to_upper() {
	printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

m4() {
	command m4 -I"$VCDK_PLUGIN_DIR" "$@"
}
